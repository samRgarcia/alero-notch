import AppKit

@main
struct AleroMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var statusItem: NSStatusItem?
    private let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchController()
        controller.start()
        self.controller = controller

        // Icono en la barra de menús para poder salir de la app.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Self.menuBarIcon()
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Ajustes…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Salir de Alero",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        item.menu = menu
        statusItem = item
    }

    /// La aleta de Alero como imagen de plantilla: macOS la pinta en negro o blanco
    /// según el tema de la barra de menús. Si falta el archivo, usa un símbolo del sistema.
    private static func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            image.accessibilityDescription = "Alero"
            return image
        }
        return NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Alero")
    }

    @objc private func openSettings() {
        guard let controller else { return }
        settingsWindow.show(settings: controller.settings)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}
