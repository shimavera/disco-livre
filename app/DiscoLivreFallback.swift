import AppKit

final class DiscoLivreFallback: NSObject, NSApplicationDelegate {
    private enum UtilityMode {
        case analysis
        case cleanupPreview
        case cleanupConfirmation
        case cleanupResult
    }

    private var item: NSStatusItem!
    private var timer: Timer?

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
        menu.addItem(NSMenuItem(title: "Limpeza manual segura…", action: #selector(cleanupAction), keyEquivalent: ""))
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
            arguments: ["limpar"],
            title: "Prévia da limpeza segura",
            message: "Esta simulação não apaga nada. Confira a lista antes de continuar.",
            mode: .cleanupPreview
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
                case .cleanupPreview:
                    self.showCleanupPreview(result)
                case .cleanupConfirmation:
                    self.showCleanupConfirmation(result)
                case .cleanupResult:
                    self.refresh()
                    self.showOutput(title: title, message: message, output: result, buttons: ["Fechar"])
                case .analysis:
                    self.showOutput(title: title, message: message, output: result, buttons: ["Fechar"])
                }
            }
        }
    }

    private func showCleanupPreview(_ output: String) {
        let hasItems = output.contains("Total:") && !output.contains("Nada pra limpar agora.")
        guard hasItems else {
            showOutput(
                title: "Nenhum item disponível para limpeza",
                message: "Não encontrei lixo seguro que possa ser removido agora.",
                output: output,
                buttons: ["Fechar"]
            )
            return
        }

        let response = showOutput(
            title: "Prévia da limpeza segura",
            message: "Nada foi apagado. Confira os itens e o total. Para prosseguir, haverá uma confirmação final.",
            output: output,
            buttons: ["Cancelar", "Continuar"]
        )
        if response == .alertSecondButtonReturn {
            confirmCleanup()
        }
    }

    private func confirmCleanup() {
        runUtility(
            arguments: ["limpar"],
            title: "Confirmação final",
            message: "A lista foi atualizada. Revise antes da confirmação final.",
            mode: .cleanupConfirmation
        )
    }

    private func showCleanupConfirmation(_ output: String) {
        let hasItems = output.contains("Total:") && !output.contains("Nada pra limpar agora.")
        guard hasItems else {
            showOutput(title: "Nada para limpar", message: "A lista mudou e não há mais itens disponíveis.", output: output, buttons: ["Fechar"])
            return
        }
        let response = showOutput(
            title: "Confirmação final",
            message: "Confirme para remover somente os itens seguros mostrados abaixo.",
            output: output,
            buttons: ["Cancelar", "Limpar agora"]
        )
        if response == .alertSecondButtonReturn {
            runUtility(
                arguments: ["limpar", "--executar", "--sim"],
                title: "Limpeza concluída",
                message: "Confira o resultado abaixo. Nenhum documento, foto ou projeto é incluído nesta limpeza.",
                mode: .cleanupResult
            )
        }
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
