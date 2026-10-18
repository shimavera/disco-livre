// Disco Livre — gaveta lateral que mostra e libera espaço no Mac.
// Encoste o mouse na borda direita da tela e ela desliza pra dentro.
// Usa a ferramenta `disco-livre` (~/.local/bin) por baixo.

import AppKit
import ServiceManagement
import SwiftUI

// MARK: - Ferramenta de linha de comando

enum CLI {
    static let caminho = NSHomeDirectory() + "/.local/bin/disco-livre"
    static let log = NSHomeDirectory() + "/Library/Logs/disco-livre.log"
    static var existe: Bool { FileManager.default.isExecutableFile(atPath: caminho) }

    static func rodar(_ args: [String]) async -> String {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                p.arguments = [caminho] + args
                let saida = Pipe()
                p.standardOutput = saida
                p.standardError = FileHandle.nullDevice
                p.standardInput = FileHandle.nullDevice
                do { try p.run() } catch { cont.resume(returning: ""); return }
                let dados = saida.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                cont.resume(returning: String(decoding: dados, as: UTF8.self))
            }
        }
    }
}

// MARK: - Dados

struct Resumo: Decodable {
    var livre: Int64
    var total: Int64
    var metaKb: Int64
    var metaGb: Int
    var vigilancia: Bool
    var autoLimpeza: Bool
    var intervalo: Int
    var tendenciaKb: Int64?
    var lixo: [Lixo]
    var crashes: [Crash]
    var tarefas: [Tarefa]
    var remoto: [Remoto]
}

struct Lixo: Decodable, Identifiable {
    var kb: Int64; var desc: String; var bloqueado: Bool; var cam: String; var manual: Bool?
    var id: String { cam }
}

struct Crash: Decodable, Identifiable {
    var n: Int; var kb: Int64; var app: String; var cam: String
    var id: String { cam }
}

struct Tarefa: Decodable, Identifiable {
    var tipo: String; var label: String; var info: String; var prog: String
    var id: String { label }
}

struct Remoto: Decodable, Identifiable {
    var app: String; var porta: String; var perfil: String
    var id: String { app + porta }
}

struct Pasta: Decodable, Identifiable {
    var kb: Int64; var cam: String; var oculta: Bool; var dica: String
    var id: String { cam }
    var nome: String { (cam as NSString).lastPathComponent }
    var curto: String { cam.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}

/// GB/MB decimais, igual ao Finder.
func tamanho(_ kb: Int64) -> String {
    let b = Double(abs(kb)) * 1024
    let f = NumberFormatter()
    f.locale = Locale(identifier: "pt_BR")
    if b >= 1e9 {
        f.minimumFractionDigits = 1; f.maximumFractionDigits = 1
        return (f.string(from: NSNumber(value: b / 1e9)) ?? "") + " GB"
    }
    f.maximumFractionDigits = 0
    if b >= 1e6 { return (f.string(from: NSNumber(value: b / 1e6)) ?? "") + " MB" }
    return "\(abs(kb)) KB"
}

@MainActor
final class Estado: ObservableObject {
    @Published var resumo: Resumo?
    @Published var pastas: [Pasta]?
    @Published var carregando = false
    @Published var medindoPastas = false
    @Published var limpando = false
    @Published var aviso: String?

    var aoAtualizar: (() -> Void)?
    private var ultimaAtualizacao = Date.distantPast
    private var tarefaMeta: Task<Void, Never>?

    func atualizar(seVelho: Bool = false) async {
        guard CLI.existe else { aoAtualizar?(); return }
        if seVelho && Date().timeIntervalSince(ultimaAtualizacao) < 60 { return }
        if carregando { return }
        carregando = true
        let txt = await CLI.rodar(["dados", "resumo"])
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        if let r = try? dec.decode(Resumo.self, from: Data(txt.utf8)) {
            resumo = r
            ultimaAtualizacao = Date()
        }
        carregando = false
        aoAtualizar?()
    }

    func medirPastas() async {
        medindoPastas = true
        let txt = await CLI.rodar(["dados", "pastas"])
        pastas = (try? JSONDecoder().decode([Pasta].self, from: Data(txt.utf8))) ?? []
        medindoPastas = false
    }

    func limpar() async {
        let antes = resumo?.livre ?? 0
        limpando = true
        aviso = nil
        _ = await CLI.rodar(["limpar", "--executar", "--sim"])
        ultimaAtualizacao = .distantPast
        await atualizar()
        limpando = false
        let ganho = (resumo?.livre ?? 0) - antes
        aviso = ganho > 102_400 ? "Pronto! Liberei \(tamanho(ganho))." : "Pronto! Lixo limpo."
    }

    func mudarMeta(_ gb: Int) {
        resumo?.metaGb = gb
        resumo?.metaKb = Int64(gb) * 976_562
        aoAtualizar?()
        tarefaMeta?.cancel()
        tarefaMeta = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            _ = await CLI.rodar(["config", "meta", "\(gb)"])
        }
    }

    func mudarVigilancia(_ ligar: Bool) async {
        resumo?.vigilancia = ligar
        _ = await CLI.rodar([ligar ? "ativar" : "desativar"])
        ultimaAtualizacao = .distantPast
        await atualizar()
    }

    func mudarAutoLimpeza(_ ligar: Bool) async {
        resumo?.autoLimpeza = ligar
        _ = await CLI.rodar(["config", "auto-limpeza", ligar ? "sim" : "nao"])
    }

    func pausar(_ label: String) async {
        _ = await CLI.rodar(["pausar-tarefa", label])
        ultimaAtualizacao = .distantPast
        await atualizar()
        aviso = "Tarefa \(label) pausada."
    }
}

// MARK: - Interface

struct BarraEspaco: View {
    let r: Resumo

    var cor: Color {
        if r.livre < r.metaKb { return .red }
        if r.livre < r.metaKb + r.metaKb / 3 { return .orange }
        return .green
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let usado = CGFloat(r.total - r.livre) / CGFloat(max(r.total, 1))
            let limite = CGFloat(r.total - r.metaKb) / CGFloat(max(r.total, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule().fill(cor.gradient).frame(width: max(8, w * usado))
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 2, height: 14)
                    .offset(x: w * limite - 1)
            }
        }
        .frame(height: 8)
        .padding(.vertical, 3)
        .help("A linha é a sua meta: o disco não deve encher além dela")
    }
}

/// Anel com o espaço livre no meio e um tique marcando a meta.
struct AnelEspaco: View {
    let r: Resumo

    var cores: [Color] {
        if r.livre < r.metaKb { return [.red, .pink] }
        if r.livre < r.metaKb + r.metaKb / 3 { return [.orange, .yellow] }
        return [Color(red: 0.16, green: 0.80, blue: 0.56), Color(red: 0.10, green: 0.55, blue: 0.95)]
    }

    var body: some View {
        let livre = CGFloat(r.livre) / CGFloat(max(r.total, 1))
        let meta = CGFloat(r.metaKb) / CGFloat(max(r.total, 1))
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: 7)
            Circle()
                .trim(from: 0, to: livre)
                .stroke(AngularGradient(colors: cores + [cores[0]], center: .center),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            // tique da meta
            Capsule()
                .fill(Color.primary.opacity(0.8))
                .frame(width: 2.5, height: 11)
                .offset(y: -29)
                .rotationEffect(.degrees(Double(meta) * 360))
            VStack(spacing: -2) {
                Text("\(Int((Double(r.livre) * 1024 / 1e9).rounded()))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("GB").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 58, height: 58)
        .help("Anel = espaço livre. Tique = sua meta.")
    }
}

/// Ícone branco num quadradinho colorido, como nos Ajustes do Sistema.
struct IconeQuadrado: View {
    let simbolo: String
    let cor: Color

    var body: some View {
        Image(systemName: simbolo)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(cor.gradient))
    }
}

/// Uma linha "ícone · rótulo ........ valor" do resumo compacto.
struct Linha<Valor: View>: View {
    let icone: String
    let cor: Color
    let titulo: String
    @ViewBuilder var valor: Valor

    var body: some View {
        HStack(spacing: 10) {
            IconeQuadrado(simbolo: icone, cor: cor)
            Text(titulo)
            Spacer(minLength: 8)
            valor
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 38)
    }
}

/// Botão em cápsula com degradê.
struct Capsula: ButtonStyle {
    let cor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(cor.gradient))
            .shadow(color: cor.opacity(0.35), radius: 3, y: 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Fundo agrupado (estilo lista dos Ajustes).
struct Grupo<Conteudo: View>: View {
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(spacing: 0) { conteudo }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

struct Secao<Conteudo: View>: View {
    let titulo: String
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            conteudo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PainelView: View {
    @EnvironmentObject var e: Estado
    @State private var detalhes = false
    @State private var confirmando = false
    @State private var iniciarComMac = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !CLI.existe {
                semFerramenta
            } else if let r = e.resumo {
                resumo(r).padding(14)
                if detalhes {
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            alertas(r)
                            lixoDetalhado(r)
                            pastas
                            ajustes(r)
                        }
                        .padding(14)
                    }
                    .frame(maxHeight: 420)
                }
                Divider()
                rodape(r)
            } else {
                HStack { ProgressView().controlSize(.small); Text("Olhando o disco…").foregroundStyle(.secondary) }
                    .padding(20)
            }
        }
        .frame(width: 300)
        .animation(.easeInOut(duration: 0.2), value: detalhes)
    }

    var semFerramenta: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Falta instalar a ferramenta").font(.headline)
            Text("Na pasta do disco-livre, rode ./install.sh no Terminal.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
    }

    // ── as 4 coisas ──────────────────────────────────────────────────────

    func resumo(_ r: Resumo) -> some View {
        let total = r.lixo.filter { !$0.bloqueado && $0.manual != true }.reduce(Int64(0)) { $0 + $1.kb }
        let ok = r.livre >= r.metaKb
        return VStack(alignment: .leading, spacing: 12) {
            // 1. espaço livre
            HStack(spacing: 14) {
                AnelEspaco(r: r)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Espaço livre").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text(tamanho(r.livre)).font(.system(size: 22, weight: .bold, design: .rounded))
                    HStack(spacing: 4) {
                        Circle().fill(ok ? Color.green : Color.red).frame(width: 6, height: 6)
                        Text(ok ? "\(tamanho(r.livre - r.metaKb)) acima da meta"
                                : "faltam \(tamanho(r.metaKb - r.livre)) pra meta")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(ok ? Color.secondary : Color.red)
                }
                Spacer()
                if e.carregando { ProgressView().controlSize(.mini) }
            }

            Grupo {
                // 2. meta
                Linha(icone: "flag.fill", cor: .blue, titulo: "Meta") {
                    HStack(spacing: 2) {
                        Button { e.mudarMeta(max(5, r.metaGb - 5)) } label: {
                            Image(systemName: "minus").frame(width: 20, height: 20)
                        }
                        Text("\(r.metaGb) GB").monospacedDigit().fontWeight(.semibold).frame(minWidth: 46)
                        Button { e.mudarMeta(min(500, r.metaGb + 5)) } label: {
                            Image(systemName: "plus").frame(width: 20, height: 20)
                        }
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                Divider().padding(.leading, 42)
                // 3. vigia
                Linha(icone: r.vigilancia ? "eye.fill" : "eye.slash.fill", cor: r.vigilancia ? .purple : .gray, titulo: "Vigia") {
                    Text(r.vigilancia ? "a cada \(r.intervalo)h" : "desligado")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Toggle("", isOn: Binding(get: { r.vigilancia }, set: { v in Task { await e.mudarVigilancia(v) } }))
                        .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                }
                Divider().padding(.leading, 42)
                // 4. pra limpar
                Linha(icone: "sparkles", cor: .green, titulo: "Pra limpar") {
                    if e.limpando {
                        ProgressView().controlSize(.mini)
                    } else if total == 0 {
                        Text("nada 👌").foregroundStyle(.secondary)
                    } else {
                        Text(tamanho(total)).monospacedDigit().foregroundStyle(.secondary)
                        Button(confirmando ? "Confirmar" : "Limpar") {
                            if confirmando {
                                confirmando = false
                                Task { await e.limpar() }
                            } else {
                                confirmando = true
                            }
                        }
                        .buttonStyle(Capsula(cor: confirmando ? .orange : .green))
                        .help("Apaga só cache, logs velhos e relatórios de crash. Tudo se recria sozinho.")
                    }
                }
            }

            if confirmando {
                HStack {
                    Text("Apagar \(tamanho(total)) de lixo seguro?").font(.caption)
                    Spacer()
                    Button("Cancelar") { confirmando = false }.buttonStyle(.borderless).font(.caption)
                }
            }
            if let a = e.aviso {
                Label(a, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
            }
        }
    }

    func rodape(_ r: Resumo) -> some View {
        let alertas = r.crashes.count + r.tarefas.count + r.remoto.count
        return HStack {
            Button {
                detalhes.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(detalhes ? "Ver menos" : "Ver mais")
                    Image(systemName: detalhes ? "chevron.up" : "chevron.down").font(.caption2)
                    if alertas > 0 && !detalhes {
                        Text("\(alertas) alerta\(alertas > 1 ? "s" : "")")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            Button { Task { await e.atualizar() } } label: { Image(systemName: "arrow.clockwise") }
                .help("Atualizar")
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // ── detalhes (Ver mais) ──────────────────────────────────────────────

    @ViewBuilder
    func alertas(_ r: Resumo) -> some View {
        if !r.crashes.isEmpty || !r.tarefas.isEmpty || !r.remoto.isEmpty {
            Secao(titulo: "Alertas") {
                ForEach(r.crashes) { c in
                    alerta("xmark.octagon.fill", .red, "\(c.app) está crashando sem parar",
                           "\(c.n) relatórios de crash (\(tamanho(c.kb))). Limpe e reinicie o app.")
                }
                ForEach(r.tarefas) { t in
                    HStack(alignment: .top) {
                        alerta(t.tipo == "reabre" ? "arrow.triangle.2.circlepath" : "exclamationmark.circle.fill",
                               t.tipo == "reabre" ? .orange : .red, t.label,
                               t.tipo == "reabre" ? "Abre o \(t.info) sozinho e reabre se você fechar."
                                                  : "Tarefa em segundo plano dando erro (código \(t.info)).")
                        Button("Pausar") { Task { await e.pausar(t.label) } }
                            .controlSize(.mini)
                            .help("Para a tarefa (reversível: disco-livre religar-tarefa \(t.label))")
                    }
                }
                ForEach(r.remoto) { rm in
                    alerta("dot.radiowaves.left.and.right", .orange, "\(rm.app) com controle remoto ligado",
                           "Qualquer programa pode comandar esse navegador. Se não é automação sua, feche.")
                }
            }
        }
    }

    func alerta(_ icone: String, _ cor: Color, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icone).foregroundStyle(cor).font(.caption).frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(titulo).font(.caption.weight(.medium)).lineLimit(2)
                Text(texto).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    func lixoDetalhado(_ r: Resumo) -> some View {
        Secao(titulo: "O que dá pra limpar") {
            if r.lixo.isEmpty {
                Text("Nada no momento.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(r.lixo.sorted { $0.kb > $1.kb }) { i in
                HStack {
                    Text(i.desc).lineLimit(1)
                    if i.bloqueado {
                        Text("feche o app").font(.caption2).foregroundStyle(.orange)
                    } else if i.manual == true {
                        Text("revisão manual").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(tamanho(i.kb)).monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.caption)
                .opacity(i.bloqueado ? 0.55 : 1)
            }
        }
    }

    var pastas: some View {
        Secao(titulo: "Maiores pastas") {
            if e.medindoPastas {
                HStack { ProgressView().controlSize(.mini); Text("Medindo… uns 15 s").foregroundStyle(.secondary) }
                    .font(.caption)
            } else if let lista = e.pastas {
                ForEach(lista.prefix(10)) { p in
                    HStack(spacing: 4) {
                        Text(p.nome).lineLimit(1).truncationMode(.middle)
                        if p.oculta {
                            Text("oculta").font(.system(size: 9, weight: .semibold)).foregroundStyle(.orange)
                        }
                        Spacer()
                        Text(tamanho(p.kb)).monospacedDigit().foregroundStyle(.secondary)
                        Button { NSWorkspace.shared.open(URL(fileURLWithPath: p.cam)) } label: {
                            Image(systemName: "arrow.up.forward.square")
                        }
                        .buttonStyle(.borderless)
                        .help(p.dica.isEmpty ? "Abrir no Finder: \(p.curto)" : "\(p.dica)\n\(p.curto)")
                    }
                    .font(.caption)
                }
            } else {
                Button("Medir pastas (inclusive as ocultas)") { Task { await e.medirPastas() } }
                    .controlSize(.small)
            }
        }
    }

    func ajustes(_ r: Resumo) -> some View {
        Secao(titulo: "Ajustes") {
            Toggle("Limpar sozinho abaixo da meta",
                   isOn: Binding(get: { r.autoLimpeza }, set: { v in Task { await e.mudarAutoLimpeza(v) } }))
                .disabled(!r.vigilancia)
            Toggle("Abrir ao ligar o Mac", isOn: Binding(get: { iniciarComMac }, set: { v in
                do {
                    if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                } catch {}
                iniciarComMac = SMAppService.mainApp.status == .enabled
            }))
            HStack {
                Button("Histórico") { NSWorkspace.shared.open(URL(fileURLWithPath: CLI.log)) }
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .font(.caption)
    }
}

// MARK: - App (ícone na barra de menus + popover)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let estado = Estado()
    let popover = NSPopover()
    var item: NSStatusItem!
    var monitores: [Any] = []
    var timerAbrir: Timer?
    var timerFechar: Timer?
    var fixo = false   // aberto com clique: só fecha com clique fora

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = item.button {
            b.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: "Disco Livre")
            b.imagePosition = .imageLeading
            b.target = self
            b.action = #selector(cliqueNoIcone)
        }

        let host = NSHostingController(rootView: PainelView().environmentObject(estado))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .applicationDefined
        popover.animates = true

        estado.aoAtualizar = { [weak self] in self?.atualizarIcone() }

        // passar o mouse no ícone abre; sair de perto fecha
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] _ in
            Task { @MainActor in self?.mouseMexeu() }
        }) { monitores.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] ev in
            Task { @MainActor in self?.mouseMexeu() }
            return ev
        }) { monitores.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            Task { @MainActor in self?.fechar() }
        }) { monitores.append(m) }

        Task { await estado.atualizar() }
        if CommandLine.arguments.contains("--mostrar") { abrir(fixo: true) }
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.estado.atualizar() }
        }
    }

    func atualizarIcone() {
        guard let b = item.button else { return }
        guard let r = estado.resumo else { b.title = ""; return }
        let gb = Int((Double(r.livre) * 1024 / 1e9).rounded())
        let abaixo = r.livre < r.metaKb
        b.title = " \(gb) GB"
        b.image = NSImage(systemSymbolName: abaixo ? "exclamationmark.triangle.fill" : "internaldrive",
                          accessibilityDescription: "Disco Livre")
        b.contentTintColor = abaixo ? .systemRed : nil
    }

    var areaDoIcone: NSRect {
        guard let b = item.button, let w = b.window else { return .zero }
        return w.convertToScreen(b.convert(b.bounds, to: nil))
    }

    var areaDoPopover: NSRect {
        popover.contentViewController?.view.window?.frame ?? .zero
    }

    func mouseMexeu() {
        let p = NSEvent.mouseLocation
        let noIcone = areaDoIcone.insetBy(dx: -2, dy: -2).contains(p)
        if !popover.isShown {
            if noIcone {
                if timerAbrir == nil {
                    timerAbrir = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            guard let self else { return }
                            self.timerAbrir = nil
                            if self.areaDoIcone.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) {
                                self.abrir(fixo: false)
                            }
                        }
                    }
                }
            } else {
                timerAbrir?.invalidate(); timerAbrir = nil
            }
            return
        }
        guard !fixo else { return }
        let perto = noIcone || areaDoPopover.insetBy(dx: -16, dy: -16).contains(p)
        if perto {
            timerFechar?.invalidate(); timerFechar = nil
        } else if timerFechar == nil {
            timerFechar = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.timerFechar = nil
                    let q = NSEvent.mouseLocation
                    if !self.areaDoIcone.contains(q) && !self.areaDoPopover.insetBy(dx: -16, dy: -16).contains(q) {
                        self.fechar(forcar: true)
                    }
                }
            }
        }
    }

    @objc func cliqueNoIcone() {
        if popover.isShown && fixo {
            fechar(forcar: true)
        } else if popover.isShown {
            fixo = true   // estava aberto pelo mouse: o clique "prende"
        } else {
            abrir(fixo: true)
        }
    }

    func abrir(fixo: Bool) {
        guard let b = item.button else { return }
        self.fixo = fixo
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        Task { await estado.atualizar(seVelho: true) }
    }

    func fechar(forcar: Bool = false) {
        guard popover.isShown else { return }
        if !forcar && areaDoPopover.contains(NSEvent.mouseLocation) { return }
        timerFechar?.invalidate(); timerFechar = nil
        fixo = false
        popover.performClose(nil)
    }
}

@main
enum DiscoLivreApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = MainActor.assumeIsolated { AppDelegate() }
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
