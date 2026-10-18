import AppKit

final class DiscoLivreFallback: NSObject, NSApplicationDelegate {
    private enum UtilityMode {
        case analysis
        case cleanupSelection
        case cleanupResult
    }

    private struct CleanupItem {
        let kb: Int
        let description: String
        let blocked: Bool
        let path: String
        let manual: Bool
    }

    private var item: NSStatusItem!
    private var timer: Timer?
    private var cleanupCheckboxes: [NSButton] = []
    private var selectAllCheckbox: NSButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        item.button?.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Disco Livre")
        item.button?.imagePosition = .imageLeading
        item.button?.toolTip = "Disco Livre — espaço disponível no Mac"
        item.menu = makeMenu()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let summary = NSMenuItem(title: "Espaço livre: carregando…", action: nil, keyEquivalent: "")
        summary.tag = 1
        summary.isEnabled = false
        menu.addItem(summary)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Analisar armazenamento…", action: #selector(analyzeAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Escolher itens para limpar…", action: #selector(cleanupAction), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Atualizar agora", action: #selector(refreshAction), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Sair", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    private func refresh() {
        guard let values = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let free = values[.systemFreeSize] as? NSNumber else { return }
        let gb = free.doubleValue / 1_000_000_000
        let formatted = String(format: "%.1f GB", gb)
        item.button?.title = formatted
        item.button?.toolTip = "Disco Livre — \(formatted) disponíveis"
        item.menu?.items.first(where: { $0.tag == 1 })?.title = "Espaço livre: \(formatted)"
    }

    @objc private func refreshAction() { refresh() }

    @objc private func analyzeAction() {
        runUtility(
            arguments: ["analisar"],
            title: "Análise do armazenamento",
            message: "O relatório é apenas informativo; não altera nem apaga arquivos.",
            mode: .analysis
        )
    }

    @objc private func cleanupAction() {
        runUtility(
            arguments: ["dados", "resumo"],
            title: "Escolha o que limpar",
            message: "Marque somente os itens que deseja remover. Nada será apagado nesta etapa.",
            mode: .cleanupSelection
        )
    }

    private func runUtility(arguments: [String], title: String, message: String, mode: UtilityMode) {
        let utility = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/bin/disco-livre")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            let output = Pipe()
            process.executableURL = utility
            process.arguments = arguments
            process.standardOutput = output
            process.standardError = output

            let result: String
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                result = String(data: data, encoding: .utf8) ?? "Não foi possível ler o relatório."
            } catch {
                result = "Não consegui executar o Disco Livre.\n\n\(error.localizedDescription)"
            }

            DispatchQueue.main.async {
                guard let self else { return }
                switch mode {
                case .cleanupSelection:
                    self.showCleanupSelection(result)
                case .cleanupResult:
                    self.refresh()
                    self.showOutput(title: title, message: message, output: result, buttons: ["Fechar"])
                case .analysis:
                    self.showOutput(title: title, message: message, output: result, buttons: ["Fechar"])
                }
            }
        }
    }

    private func showCleanupSelection(_ output: String) {
        guard let data = output.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawItems = root["lixo"] as? [[String: Any]] else {
            showOutput(title: "Não consegui listar os itens", message: "Tente novamente em instantes.", output: output, buttons: ["Fechar"])
            return
        }
        let trashAvailable = root["lixeira_disponivel"] as? Bool ?? true

        let items = rawItems.compactMap { row -> CleanupItem? in
            guard let kb = row["kb"] as? Int,
                  let description = row["desc"] as? String,
                  let blocked = row["bloqueado"] as? Bool,
                  let path = row["cam"] as? String else { return nil }
            return CleanupItem(kb: kb, description: description, blocked: blocked, path: path,
                               manual: row["manual"] as? Bool ?? false)
        }
        guard !items.isEmpty else {
            let message = trashAvailable
                ? "Não encontrei itens para limpeza seletiva."
                : "Não consegui consultar a Lixeira. Permita que o Disco Livre controle o Finder em Ajustes do Sistema, em Privacidade e Segurança > Automação."
            showOutput(title: "Nada para limpar", message: message, output: "Nenhum item de limpeza elegível foi encontrado.", buttons: ["Fechar"])
            return
        }

        cleanupCheckboxes.removeAll()
        let contentHeight = max(230, CGFloat(items.count + 1) * 30 + 12)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: contentHeight))
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -8)
        ])

        let selectAll = NSButton(checkboxWithTitle: "Selecionar todos os itens disponíveis", target: self, action: #selector(toggleAllCheckboxes(_:)))
        selectAll.isEnabled = items.contains(where: { !$0.blocked })
        stack.addArrangedSubview(selectAll)
        selectAllCheckbox = selectAll

        for item in items {
            let suffix = item.blocked ? " — feche o app para liberar" : (item.manual ? " — revisão manual" : "")
            let checkbox = NSButton(checkboxWithTitle: "\(humanSize(item.kb))  ·  \(item.description)\(suffix)", target: nil, action: nil)
            checkbox.isEnabled = !item.blocked
            checkbox.state = .off
            checkbox.identifier = NSUserInterfaceItemIdentifier(item.path)
            cleanupCheckboxes.append(checkbox)
            stack.addArrangedSubview(checkbox)
        }

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 230))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.documentView = content

        let alert = NSAlert()
        alert.messageText = "Escolha o que apagar"
        let trashNotice = trashAvailable
            ? "A consulta da Lixeira usa Finder e pode pedir autorização de Automação no macOS."
            : "A Lixeira não ficou disponível. Em Ajustes do Sistema, permita o controle do Finder em Privacidade e Segurança > Automação."
        alert.informativeText = "Selecione um, alguns ou todos. \(trashNotice) Nada será apagado até a confirmação final."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Cancelar")
        alert.addButton(withTitle: "Continuar")
        alert.accessoryView = scroll
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertSecondButtonReturn {
            let selected = zip(items, cleanupCheckboxes).compactMap { pair in
                let (item, checkbox) = pair
                return checkbox.state == .on ? item : nil
            }
            guard !selected.isEmpty else {
                showOutput(title: "Nenhum item selecionado", message: "Marque pelo menos um item para continuar.", output: "Nada foi apagado.", buttons: ["Fechar"])
                return
            }
            confirmSelectedItems(selected)
        }
    }

    @objc private func toggleAllCheckboxes(_ sender: NSButton) {
        for checkbox in cleanupCheckboxes where checkbox.isEnabled {
            checkbox.state = sender.state
        }
    }

    private func confirmSelectedItems(_ items: [CleanupItem]) {
        let total = items.reduce(0) { $0 + $1.kb }
        let list = items.map { "• \(humanSize($0.kb))  \($0.description)" }.joined(separator: "\n")
        let summary = "\(list)\n\nTotal selecionado: \(humanSize(total))\n\nItens da Lixeira e capturas pessoais só são removidos após esta confirmação. Isso libera espaço de armazenamento no disco; não limpa memória RAM."
        if showOutput(
            title: "Confirmação final",
            message: "Só os itens abaixo serão removidos. Deseja continuar?",
            output: summary,
            buttons: ["Cancelar", "Apagar selecionados"]
        ) == .alertSecondButtonReturn {
            var arguments = ["limpar", "--executar", "--sim"]
            for item in items { arguments += ["--item", item.path] }
            runUtility(
                arguments: arguments,
                title: "Resultado da limpeza",
                message: "A ferramenta só processa os caminhos seguros selecionados e valida novamente se continuam elegíveis.",
                mode: .cleanupResult
            )
        }
    }

    private func humanSize(_ kb: Int) -> String {
        let bytes = Double(kb) * 1024
        if bytes >= 1_000_000_000 { return String(format: "%.1f GB", bytes / 1_000_000_000) }
        if bytes >= 1_000_000 { return String(format: "%.0f MB", bytes / 1_000_000) }
        return String(format: "%.0f KB", Double(kb))
    }

    @discardableResult
    private func showOutput(title: String, message: String, output: String, buttons: [String]) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        buttons.forEach { alert.addButton(withTitle: $0) }

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 230))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 230))
        text.isEditable = false
        text.isSelectable = true
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.string = output.isEmpty ? "O comando terminou sem detalhes." : output
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.containerSize = NSSize(width: 520, height: CGFloat.greatestFiniteMagnitude)
        text.layoutManager?.ensureLayout(for: text.textContainer!)
        let contentHeight = (text.layoutManager?.usedRect(for: text.textContainer!).height ?? 230) + 16
        text.frame = NSRect(x: 0, y: 0, width: 520, height: max(230, contentHeight))
        scroll.documentView = text
        alert.accessoryView = scroll

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let discoLivreApp = NSApplication.shared
let discoLivreDelegate = DiscoLivreFallback()
discoLivreApp.delegate = discoLivreDelegate
discoLivreApp.setActivationPolicy(.accessory)
discoLivreApp.run()
