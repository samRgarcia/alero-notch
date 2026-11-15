import AppKit
import AudioToolbox
import CoreAudio
import ServiceManagement
import SwiftUI

// MARK: - Ajustes

/// Preferencias del usuario, guardadas en UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    @Published var hiddenTabs: Set<String> {
        didSet { UserDefaults.standard.set(Array(hiddenTabs), forKey: "alero.hiddenTabs") }
    }
    /// Segundos que el cursor debe quedarse en el notch antes de abrir.
    @Published var openDelay: Double {
        didSet { UserDefaults.standard.set(openDelay, forKey: "alero.openDelay") }
    }
    @Published var haptics: Bool {
        didSet { UserDefaults.standard.set(haptics, forKey: "alero.haptics") }
    }
    @Published var showMediaIndicator: Bool {
        didSet { UserDefaults.standard.set(showMediaIndicator, forKey: "alero.showMedia") }
    }
    @Published var showChargeNotice: Bool {
        didSet { UserDefaults.standard.set(showChargeNotice, forKey: "alero.showCharge") }
    }
    @Published var showVolumeHUD: Bool {
        didSet { UserDefaults.standard.set(showVolumeHUD, forKey: "alero.showVolume") }
    }
    @Published var showBrightnessHUD: Bool {
        didSet { UserDefaults.standard.set(showBrightnessHUD, forKey: "alero.showBrightness") }
    }
    /// La onda animada es la única animación continua de la app.
    @Published var animateIndicator: Bool {
        didSet { UserDefaults.standard.set(animateIndicator, forKey: "alero.animateIndicator") }
    }

    init() {
        let defaults = UserDefaults.standard
        hiddenTabs = Set(defaults.stringArray(forKey: "alero.hiddenTabs") ?? [])
        openDelay = defaults.double(forKey: "alero.openDelay")
        haptics = (defaults.object(forKey: "alero.haptics") as? Bool) ?? true
        showMediaIndicator = (defaults.object(forKey: "alero.showMedia") as? Bool) ?? true
        showChargeNotice = (defaults.object(forKey: "alero.showCharge") as? Bool) ?? true
        showVolumeHUD = (defaults.object(forKey: "alero.showVolume") as? Bool) ?? true
        showBrightnessHUD = (defaults.object(forKey: "alero.showBrightness") as? Bool) ?? true
        animateIndicator = (defaults.object(forKey: "alero.animateIndicator") as? Bool) ?? true
    }

    /// Pestañas visibles. Si se ocultan todas, se muestra la de música.
    var visibleTabs: [AleroTab] {
        let tabs = AleroTab.allCases.filter { !hiddenTabs.contains($0.rawValue) }
        return tabs.isEmpty ? [.music] : tabs
    }

    /// Pestaña que se muestra: la elegida, o la primera visible si esa está oculta.
    func activeTab(for selected: AleroTab) -> AleroTab {
        let visible = visibleTabs
        return visible.contains(selected) ? selected : (visible.first ?? .music)
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section(tr("Pestañas del panel", "Panel tabs")) {
                ForEach(AleroTab.allCases) { tab in
                    Toggle(tab.title, isOn: tabBinding(tab))
                }
            }
            Section("Notch") {
                Picker(tr("Abrir al pasar el cursor", "Open on hover"), selection: $settings.openDelay) {
                    Text(tr("Al instante", "Instantly")).tag(0.0)
                    Text(tr("Tras 0.2 segundos", "After 0.2 seconds")).tag(0.2)
                    Text(tr("Tras 0.5 segundos", "After 0.5 seconds")).tag(0.5)
                }
                Toggle(tr("Vibración del trackpad al abrir", "Trackpad haptic feedback on open"), isOn: $settings.haptics)
            }
            Section(tr("Indicadores con el panel cerrado", "Indicators while the panel is closed")) {
                Toggle(tr("Audio en reproducción", "Audio playing"), isOn: $settings.showMediaIndicator)
                Toggle(tr("Animar la onda de audio (usa algo más de GPU)", "Animate the audio wave (uses a bit more GPU)"), isOn: $settings.animateIndicator)
                Toggle(tr("Cargador conectado", "Charger connected"), isOn: $settings.showChargeNotice)
                Toggle(tr("Cambios de volumen", "Volume changes"), isOn: $settings.showVolumeHUD)
                Toggle(tr("Cambios de brillo", "Brightness changes"), isOn: $settings.showBrightnessHUD)
            }
            Section("General") {
                Toggle(tr("Abrir Alero al iniciar sesión", "Open Alero at login"), isOn: loginBinding)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
    }

    private func tabBinding(_ tab: AleroTab) -> Binding<Bool> {
        Binding(
            get: { !settings.hiddenTabs.contains(tab.rawValue) },
            set: { visible in
                if visible {
                    settings.hiddenTabs.remove(tab.rawValue)
                } else {
                    settings.hiddenTabs.insert(tab.rawValue)
                }
            }
        )
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enable in
                do {
                    if enable {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Si macOS lo rechaza, el interruptor vuelve a su estado real.
                }
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        )
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(settings: AppSettings) {
        if window == nil {
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            created.title = tr("Ajustes de Alero", "Alero Settings")
            created.isReleasedWhenClosed = false
            created.contentView = NSHostingView(rootView: SettingsView().environmentObject(settings))
            created.center()
            window = created
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Indicadores de volumen y brillo

enum HUDKind: Equatable {
    case volume, brightness
}

/// Lee el volumen de la salida de audio actual (API pública de CoreAudio).
enum AudioVolume {
    /// 'vmvc': volumen principal virtual del dispositivo.
    static let volumeSelector = AudioObjectPropertySelector(0x766D_7663)

    static func defaultDevice() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != 0 else { return nil }
        return device
    }

    static func read() -> (level: Float, muted: Bool)? {
        guard let device = defaultDevice() else { return nil }

        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: volumeSelector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr else { return nil }

        var mute = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        let hasMute = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &mute) == noErr
        return (volume, hasMute && mute != 0)
    }
}

/// Lee el brillo de la pantalla integrada con el framework privado DisplayServices.
/// Si no está disponible, devuelve `nil` y el indicador de brillo no aparece.
final class BrightnessReader {
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private let function: GetBrightness?

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        if let handle = dlopen(path, RTLD_LAZY), let symbol = dlsym(handle, "DisplayServicesGetBrightness") {
            function = unsafeBitCast(symbol, to: GetBrightness.self)
        } else {
            function = nil
        }
    }

    func read() -> Float? {
        guard let function else { return nil }
        var value: Float = 0
        return function(CGMainDisplayID(), &value) == 0 ? value : nil
    }
}

/// Detecta cambios de volumen y brillo y los muestra un momento junto al notch.
@MainActor
final class HUDService: ObservableObject {
    @Published var kind: HUDKind?
    @Published var value: Double = 0
    @Published var muted = false

    private let brightness = BrightnessReader()
    private var lastVolume: Float?
    private var lastMuted = false
    private var lastBrightness: Float?
    private var token = 0
    private var volumeEnabled = true
    private var volumeListening = false
    private var observedDevices: Set<AudioDeviceID> = []

    /// Se suscribe a los avisos de CoreAudio para no tener que consultar el volumen
    /// varias veces por segundo. Si la suscripción falla, `poll` lo consulta.
    func start() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Cambió la salida de audio (por ejemplo, se conectaron audífonos).
                self.volumeListening = self.observeCurrentDevice()
                self.checkVolume()
            }
        }
        volumeListening = status == noErr && observeCurrentDevice()
        checkVolume()
    }

    private func observeCurrentDevice() -> Bool {
        guard let device = AudioVolume.defaultDevice() else { return false }
        if observedDevices.contains(device) { return true }
        var volumeObserved = false
        for selector in [AudioVolume.volumeSelector, kAudioDevicePropertyMute] {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 0
            )
            let status = AudioObjectAddPropertyListenerBlock(device, &address, DispatchQueue.main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.checkVolume() }
            }
            if selector == AudioVolume.volumeSelector { volumeObserved = status == noErr }
        }
        if volumeObserved { observedDevices.insert(device) }
        return volumeObserved
    }

    private func checkVolume() {
        guard let current = AudioVolume.read() else {
            lastVolume = nil
            return
        }
        if volumeEnabled, let previous = lastVolume,
           abs(previous - current.level) > 0.004 || lastMuted != current.muted {
            show(.volume, value: Double(current.level), muted: current.muted)
        }
        lastVolume = current.level
        lastMuted = current.muted
    }

    /// El brillo no tiene avisos públicos, así que se consulta aquí.
    /// El volumen solo se consulta si la suscripción de `start` no funcionó.
    func poll(volume volumeEnabled: Bool, brightness brightnessEnabled: Bool) {
        self.volumeEnabled = volumeEnabled
        if !volumeListening { checkVolume() }
        if brightnessEnabled, let current = brightness.read() {
            if let previous = lastBrightness {
                // Umbral alto para ignorar el ajuste automático gradual de brillo.
                if abs(previous - current) > 0.03 {
                    show(.brightness, value: Double(current), muted: false)
                    lastBrightness = current
                }
            } else {
                lastBrightness = current
            }
        }
    }

    private func show(_ kind: HUDKind, value: Double, muted: Bool) {
        self.kind = kind
        self.value = value
        self.muted = muted
        token += 1
        let current = token
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            if current == self.token { self.kind = nil }
        }
    }
}

// MARK: - Portapapeles

struct ClipItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

/// Guarda en memoria los últimos textos copiados. Ignora lo que los gestores
/// de contraseñas marcan como oculto. Se vacía al cerrar la app.
@MainActor
final class ClipboardService: ObservableObject {
    @Published var items: [ClipItem] = []

    private var changeCount = NSPasteboard.general.changeCount

    func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        let hidden = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        let types = pasteboard.types ?? []
        if types.contains(where: { hidden.contains($0.rawValue) }) { return }

        guard let raw = pasteboard.string(forType: .string) else { return }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        add(text)
    }

    func copy(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        changeCount = pasteboard.changeCount
        add(item.text)
    }

    func clear() {
        items.removeAll()
    }

    private func add(_ text: String) {
        items.removeAll { $0.text == text }
        items.insert(ClipItem(text: text), at: 0)
        if items.count > 20 { items.removeLast(items.count - 20) }
    }
}

struct ClipboardView: View {
    @EnvironmentObject var clipboard: ClipboardService

    var body: some View {
        if clipboard.items.isEmpty {
            EmptyHint(icon: "doc.on.clipboard", text: tr("Lo que copies aparecerá aquí.\nHaz clic en un texto para volver a copiarlo.", "What you copy will show up here.\nClick a text to copy it again."))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tr("Últimos \(clipboard.items.count) textos copiados", "Last \(clipboard.items.count) copied texts"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                    Button(tr("Borrar historial", "Clear history")) { clipboard.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(clipboard.items) { item in
                            Button {
                                clipboard.copy(item)
                            } label: {
                                HStack(spacing: 10) {
                                    Text(item.text)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(tr("Copiar de nuevo", "Copy again"))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Barra de progreso de la canción

struct ProgressRow: View {
    @EnvironmentObject var music: MusicService
    let duration: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = music.position(at: context.date) ?? 0
            let fraction = CGFloat(min(max(position / duration, 0), 1))
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: max(4, geometry.size.width * fraction))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onEnded { value in
                            let width = max(geometry.size.width, 1)
                            let target = min(max(value.location.x / width, 0), 1)
                            music.seek(to: duration * Double(target))
                        }
                    )
                }
                .frame(height: 5)

                HStack {
                    Text(Self.clock(position))
                    Spacer()
                    Text(Self.clock(duration))
                }
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }

    private static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Color de la carátula

extension NSImage {
    /// Copia reducida cuyo lado más corto mide `minSide` puntos (al doble de píxeles para Retina).
    func downscaled(minSide: CGFloat) -> NSImage {
        let shortest = min(size.width, size.height)
        guard shortest > minSide else { return self }
        let scale = minSide / shortest
        let target = NSSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(target.width) * 2,
            pixelsHigh: Int(target.height) * 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return self }
        rep.size = target
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: target)
        result.addRepresentation(rep)
        return result
    }

    /// Color promedio de la imagen, para teñir el fondo del reproductor.
    var averageColor: NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return nil }
        return NSColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
    }
}
