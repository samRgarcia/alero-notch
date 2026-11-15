import AppKit
import SwiftUI

/// Pestañas del panel expandido.
enum AleroTab: String, CaseIterable, Identifiable {
    case music, files, calendar, notes, clipboard, monitor

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .files: return "tray.full"
        case .calendar: return "calendar"
        case .notes: return "note.text"
        case .clipboard: return "doc.on.clipboard"
        case .monitor: return "cpu"
        }
    }

    var title: String {
        switch self {
        case .music: return tr("Música", "Music")
        case .files: return tr("Archivos", "Files")
        case .calendar: return tr("Calendario", "Calendar")
        case .notes: return tr("Notas y temporizador", "Notes and timer")
        case .clipboard: return tr("Portapapeles", "Clipboard")
        case .monitor: return tr("Monitor de recursos", "Resource monitor")
        }
    }
}

/// Estado compartido entre la ventana y las vistas.
@MainActor
final class NotchState: ObservableObject {
    @Published var expanded = false
    @Published var tab: AleroTab = .music
    @Published var notchSize = CGSize(width: 190, height: 32)

    let fullWidth: CGFloat = 660
    let bodyHeight: CGFloat = 190

    var fullSize: CGSize {
        CGSize(width: fullWidth, height: notchSize.height + bodyHeight)
    }
}

/// Panel sin bordes que puede recibir teclado (para las notas) sin activar la app.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Crea la ventana sobre el notch y decide cuándo abrirla o cerrarla
/// según la posición del cursor.
@MainActor
final class NotchController {
    let state = NotchState()
    let music = MusicService()
    let tray = FileTray()
    let calendar = CalendarService()
    let countdown = CountdownTimer()
    let battery = BatteryService()
    let settings = AppSettings()
    let hud = HUDService()
    let clipboard = ClipboardService()
    let monitor = ResourceMonitor()

    private var panel: NotchPanel?
    private var poll: Timer?
    private var screenObserver: NSObjectProtocol?
    private var sleepObservers: [NSObjectProtocol] = []
    private var collapsedRect = NSRect.zero
    private var awayTicks = 0
    private var hoverTicks = 0
    private var enteredWhileDragging = false
    private var tickCount = 0

    func start() {
        let panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let root = NotchRootView()
            .environmentObject(state)
            .environmentObject(music)
            .environmentObject(tray)
            .environmentObject(calendar)
            .environmentObject(countdown)
            .environmentObject(battery)
            .environmentObject(settings)
            .environmentObject(hud)
            .environmentObject(clipboard)
            .environmentObject(monitor)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        panel.contentView = hosting
        self.panel = panel

        layout()
        panel.orderFrontRegardless()

        battery.start()
        hud.start()
        music.start()
        music.refresh()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        }

        // Con la pantalla apagada no hay nada que vigilar: se pausa el sondeo.
        let workspace = NSWorkspace.shared.notificationCenter
        sleepObservers = [
            workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stopPolling() }
            },
            workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.startPolling() }
            }
        ]
        startPolling()
    }

    private func startPolling() {
        guard poll == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // La tolerancia deja que macOS agrupe este temporizador con otros y ahorre energía.
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        poll = timer
    }

    private func stopPolling() {
        poll?.invalidate()
        poll = nil
    }

    /// Detiene el sondeo y el proceso auxiliar de audio al salir.
    func stop() {
        stopPolling()
        music.stop()
    }

    /// Coloca la ventana centrada en el borde superior de la pantalla con notch
    /// (o de la pantalla principal si no hay notch).
    private func layout() {
        guard let panel else { return }
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }

        var notch = CGSize(width: 190, height: 28)
        if screen.safeAreaInsets.top > 0 {
            notch.height = screen.safeAreaInsets.top
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                notch.width = screen.frame.width - left.width - right.width + 4
            }
        } else {
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            notch.height = max(24, menuBar)
        }
        state.notchSize = notch

        let size = state.fullSize
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)

        collapsedRect = NSRect(
            x: screen.frame.midX - notch.width / 2,
            y: screen.frame.maxY - notch.height,
            width: notch.width,
            height: notch.height
        )
    }

    private func tick() {
        guard let panel else { return }
        tickCount += 1
        let mouse = NSEvent.mouseLocation
        let dragging = (NSEvent.pressedMouseButtons & 1) == 1

        // Batería, volumen y audio del sistema avisan solos cuando cambian.
        // Aquí solo se sondea lo que no tiene avisos, y con la menor frecuencia útil.
        if tickCount % 300 == 0 { battery.refresh() }
        if state.expanded {
            if tickCount % 20 == 0 { music.refresh() }
        } else if settings.showMediaIndicator, tickCount % 50 == 0 {
            music.refresh()
        }
        if tickCount % 3 == 0 {
            hud.poll(volume: settings.showVolumeHUD, brightness: settings.showBrightnessHUD)
        }
        if tickCount % 10 == 0, !settings.hiddenTabs.contains(AleroTab.clipboard.rawValue) {
            clipboard.poll()
        }
        // El monitor de recursos solo mide mientras su pestaña está a la vista.
        if state.expanded, tickCount % 25 == 0, settings.activeTab(for: state.tab) == .monitor {
            monitor.refresh()
        }

        if !state.expanded {
            let hotZone = collapsedRect.insetBy(dx: -6, dy: -6)
            if hotZone.contains(mouse) {
                hoverTicks += 1
                if dragging && enteredWhileDragging {
                    // Llegó arrastrando algo: abre directo la bandeja de archivos.
                    state.tab = .files
                    expand()
                } else if Double(hoverTicks) * 0.1 >= settings.openDelay {
                    expand()
                }
            } else {
                hoverTicks = 0
                enteredWhileDragging = dragging
            }
            return
        }

        let stayZone = panel.frame.insetBy(dx: -14, dy: -14)
        if stayZone.contains(mouse) {
            awayTicks = 0
        } else if !dragging {
            awayTicks += 1
            if awayTicks >= 4 { collapse() }
        }
    }

    private func expand() {
        guard let panel else { return }
        awayTicks = 0
        hoverTicks = 0
        if settings.haptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        panel.ignoresMouseEvents = false
        state.expanded = true
        music.refresh()
        if settings.visibleTabs.contains(.calendar) { calendar.load() }
    }

    private func collapse() {
        guard let panel else { return }
        panel.makeFirstResponder(nil)
        panel.ignoresMouseEvents = true
        state.expanded = false
    }
}
