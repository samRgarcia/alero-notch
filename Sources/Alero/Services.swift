import AppKit
import EventKit
import IOKit.ps
import SwiftUI

// MARK: - Música y audio del sistema

struct TrackInfo: Sendable, Equatable {
    var title: String
    var artist: String
    var isPlaying: Bool
    var artworkURL: URL?
    var artworkData: Data?
    /// Duración en segundos, si la fuente la informa.
    var duration: Double?
    /// Nombre de la app para AppleScript ("Spotify" o "Music"). Vacío en modo sistema.
    var player: String
    /// Nombre visible de la app que reproduce.
    var playerName: String
}

/// Una actualización recibida del adaptador de audio del sistema.
struct StreamUpdate: Sendable {
    var title: String
    var artist: String
    var playing: Bool
    var bundleID: String?
    var artworkData: Data?
    var duration: Double?
    var elapsed: Double?
}

enum StreamParseResult: Sendable {
    case invalid
    case empty
    case track(StreamUpdate)
}

/// Junta los bytes que llegan del proceso auxiliar y los separa por líneas.
final class LineBuffer: @unchecked Sendable {
    private var data = Data()

    func append(_ chunk: Data) -> [Data] {
        data.append(chunk)
        var lines: [Data] = []
        while let index = data.firstIndex(of: 0x0A) {
            lines.append(data.subdata(in: data.startIndex..<index))
            data.removeSubrange(data.startIndex...index)
        }
        return lines
    }
}

/// Muestra lo que está sonando y envía comandos de reproducción.
///
/// Tiene dos modos:
/// - **Sistema**: si la app incluye el adaptador de MediaRemote (lo agrega `build-app.sh`),
///   lee cualquier fuente de audio: navegador, reproductores de video, Spotify, etc.
/// - **AppleScript**: si no hay adaptador, solo lee Spotify y Música.
@MainActor
final class MusicService: ObservableObject {
    @Published var track: TrackInfo?
    @Published var artwork: NSImage?
    /// Color promedio de la carátula, para el fondo del reproductor.
    @Published var tint: Color?
    @Published private(set) var usesSystemMedia = false

    // Posición de reproducción: último valor informado y cuándo se recibió.
    private var reportedElapsed: Double?
    private var elapsedAnchor: Double?
    private var anchorDate = Date()

    private let queue = DispatchQueue(label: "alero.music")
    private var stream: Process?
    private var adapter: (script: String, framework: String)?

    // MARK: Modo sistema

    func start() {
        guard let resources = Bundle.main.resourceURL else { return }
        let script = resources.appendingPathComponent("mediaremote-adapter.pl").path
        let framework = resources.appendingPathComponent("MediaRemoteAdapter.framework").path
        let files = FileManager.default
        guard files.fileExists(atPath: script), files.fileExists(atPath: framework) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script, framework, "stream", "--no-diff", "--debounce=200"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let buffer = LineBuffer()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            for line in buffer.append(data) {
                let result = MusicService.parse(line)
                Task { @MainActor in self?.handle(result) }
            }
        }
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.streamEnded() }
        }

        do {
            try process.run()
            stream = process
            adapter = (script, framework)
            usesSystemMedia = true
        } catch {
            adapter = nil
        }
    }

    func stop() {
        stream?.terminationHandler = nil
        stream?.terminate()
        stream = nil
    }

    /// Si el adaptador deja de funcionar (por ejemplo, tras una actualización de macOS),
    /// vuelve al modo AppleScript.
    private func streamEnded() {
        stream = nil
        adapter = nil
        usesSystemMedia = false
        refresh()
    }

    private func handle(_ result: StreamParseResult) {
        switch result {
        case .invalid:
            return
        case .empty:
            track = nil
            artwork = nil
            tint = nil
            elapsedAnchor = nil
            reportedElapsed = nil
        case .track(let update):
            var data = update.artworkData
            // La carátula suele llegar después; conserva la anterior si es la misma canción.
            if data == nil, let old = track, old.title == update.title, old.artist == update.artist {
                data = old.artworkData
            }
            let info = TrackInfo(
                title: update.title,
                artist: update.artist,
                isPlaying: update.playing,
                artworkURL: nil,
                artworkData: data,
                duration: update.duration,
                player: "",
                playerName: Self.appName(update.bundleID)
            )
            let songChanged = track?.title != info.title || track?.artist != info.artist
            if songChanged || update.elapsed != reportedElapsed || update.playing != track?.isPlaying {
                reportedElapsed = update.elapsed
                elapsedAnchor = update.elapsed
                anchorDate = Date()
            }
            if info.artworkData != track?.artworkData {
                // Se guarda una versión reducida: dibujar la carátula original
                // (a veces de miles de píxeles) en cada animación gasta GPU y memoria.
                let original = data.flatMap { NSImage(data: $0) }
                tint = original?.averageColor.map { Color(nsColor: $0) }
                artwork = original?.downscaled(minSide: 240)
            }
            if info != track { track = info }
        }
    }

    nonisolated static func parse(_ line: Data) -> StreamParseResult {
        guard let object = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let payload = object["payload"] as? [String: Any] else { return .invalid }
        guard let title = payload["title"] as? String, !title.isEmpty else { return .empty }
        let art = (payload["artworkData"] as? String).flatMap {
            Data(base64Encoded: $0, options: .ignoreUnknownCharacters)
        }
        let bundle = (payload["parentApplicationBundleIdentifier"] as? String)
            ?? (payload["bundleIdentifier"] as? String)
        return .track(
            StreamUpdate(
                title: title,
                artist: (payload["artist"] as? String) ?? "",
                playing: (payload["playing"] as? Bool) ?? false,
                bundleID: bundle,
                artworkData: art,
                duration: (payload["duration"] as? NSNumber)?.doubleValue,
                elapsed: (payload["elapsedTime"] as? NSNumber)?.doubleValue
            )
        )
    }

    private static func appName(_ bundleID: String?) -> String {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return "" }
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    // MARK: Modo AppleScript

    /// Consulta Spotify y Música. No hace nada en modo sistema (ahí llegan avisos solos).
    func refresh() {
        guard !usesSystemMedia else { return }
        let spotify = Self.isRunning("com.spotify.client")
        let music = Self.isRunning("com.apple.Music")
        queue.async { [weak self] in
            let result = MusicService.query(spotify: spotify, music: music)
            Task { @MainActor in
                guard let self, !self.usesSystemMedia else { return }
                if self.track != result { self.track = result }
                if self.artwork != nil { self.artwork = nil }
                if self.tint != nil { self.tint = nil }
            }
        }
    }

    private static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    nonisolated static func query(spotify: Bool, music: Bool) -> TrackInfo? {
        var apps: [String] = []
        if spotify { apps.append("Spotify") }
        if music { apps.append("Music") }

        var paused: TrackInfo?
        for app in apps {
            let art = app == "Spotify" ? " & (artwork url of t)" : ""
            let source = """
            tell application "\(app)"
                if player state is stopped then return ""
                set t to current track
                return (name of t) & "|||" & (artist of t) & "|||" & (player state as string) & "|||"\(art)
            end tell
            """
            guard let out = run(source), !out.isEmpty else { continue }
            let parts = out.components(separatedBy: "|||")
            guard parts.count >= 3 else { continue }
            let info = TrackInfo(
                title: parts[0],
                artist: parts[1],
                isPlaying: parts[2].lowercased().contains("playing"),
                artworkURL: parts.count > 3 ? URL(string: parts[3]) : nil,
                artworkData: nil,
                duration: nil,
                player: app,
                playerName: app == "Music" ? "Música" : app
            )
            if info.isPlaying { return info }
            if paused == nil { paused = info }
        }
        return paused
    }

    nonisolated static func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return output.stringValue ?? ""
    }

    // MARK: Posición

    /// Segundo actual de la canción, o `nil` si la fuente no informa duración.
    func position(at date: Date) -> Double? {
        guard let track, let duration = track.duration, duration > 0,
              let anchor = elapsedAnchor else { return nil }
        let moved = track.isPlaying ? date.timeIntervalSince(anchorDate) : 0
        return min(max(anchor + moved, 0), duration)
    }

    func seek(to seconds: Double) {
        guard adapter != nil else { return }
        runAdapter(["seek", String(Int(seconds * 1_000_000))])
        elapsedAnchor = seconds
        anchorDate = Date()
        objectWillChange.send()
    }

    private func runAdapter(_ arguments: [String]) {
        guard let adapter else { return }
        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = [adapter.script, adapter.framework] + arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                // Sin adaptador disponible no hay nada que enviar.
            }
        }
    }

    // MARK: Comandos

    func playPause() { send(systemID: "2", script: "playpause") }
    func next() { send(systemID: "4", script: "next track") }
    func previous() { send(systemID: "5", script: "previous track") }

    private func send(systemID: String, script command: String) {
        if adapter != nil {
            runAdapter(["send", systemID])
            return
        }
        guard let app = track?.player, !app.isEmpty else { return }
        queue.async { [weak self] in
            _ = MusicService.run("tell application \"\(app)\" to \(command)")
            Task { @MainActor in self?.refresh() }
        }
    }
}

// MARK: - Batería

/// Lee el nivel de batería y avisa unos segundos cuando se conecta el cargador.
@MainActor
final class BatteryService: ObservableObject {
    /// Porcentaje de 0 a 100. `nil` si el equipo no tiene batería.
    @Published var level: Int?
    @Published var charging = false
    @Published var pluggedIn = false
    @Published var showChargeNotice = false

    private var loadedOnce = false
    private var noticeToken = 0
    private var runLoopSource: CFRunLoopSource?

    /// Pide a macOS que avise cuando cambie la batería o el cargador,
    /// en vez de consultarlo cada pocos segundos.
    func start() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.refresh() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = source
        }
    }

    func refresh() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return }

        var newLevel: Int?
        var newCharging = false
        var newPlugged = false
        for source in list {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            let current = (info[kIOPSCurrentCapacityKey] as? Int) ?? 0
            let maximum = (info[kIOPSMaxCapacityKey] as? Int) ?? 100
            newLevel = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : current
            newCharging = (info[kIOPSIsChargingKey] as? Bool) ?? false
            newPlugged = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        }

        let justPlugged = loadedOnce && newPlugged && !pluggedIn && newLevel != nil
        loadedOnce = true
        if level != newLevel { level = newLevel }
        if charging != newCharging { charging = newCharging }
        if pluggedIn != newPlugged { pluggedIn = newPlugged }

        if justPlugged {
            noticeToken += 1
            let token = noticeToken
            showChargeNotice = true
            Task {
                try? await Task.sleep(for: .seconds(4))
                if token == self.noticeToken { self.showChargeNotice = false }
            }
        } else if !newPlugged, showChargeNotice {
            showChargeNotice = false
        }
    }
}

// MARK: - Bandeja de archivos

/// Guarda referencias a los archivos soltados (no los copia ni los mueve).
/// La lista se conserva entre sesiones; los archivos que ya no existen se descartan.
@MainActor
final class FileTray: ObservableObject {
    @Published var items: [URL] = [] {
        didSet { UserDefaults.standard.set(items.map(\.path), forKey: "alero.tray") }
    }

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: "alero.tray") ?? []
        items = saved
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    func airdrop() {
        guard !items.isEmpty else { return }
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: items)
    }

    func add(_ url: URL) {
        guard !items.contains(url) else { return }
        items.append(url)
    }

    func remove(_ url: URL) {
        items.removeAll { $0 == url }
    }

    func clear() {
        items.removeAll()
    }
}

// MARK: - Calendario

struct EventItem: Identifiable, Equatable {
    var id: String
    var title: String
    var start: Date
    var isAllDay: Bool
    /// Enlace de videollamada (Meet, Zoom, Teams o Webex), si el evento trae uno.
    var joinURL: URL?
}

@MainActor
final class CalendarService: ObservableObject {
    @Published var events: [EventItem] = []
    @Published var denied = false

    private let store = EKEventStore()
    private var lastLoad = Date.distantPast

    /// Vuelve a leer el calendario como máximo una vez por minuto.
    func load() {
        guard Date().timeIntervalSince(lastLoad) > 60 else { return }
        lastLoad = Date()
        store.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in self?.finish(granted: granted) }
        }
    }

    private func finish(granted: Bool) {
        denied = !granted
        guard granted else {
            events = []
            return
        }
        let now = Date()
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(172_800)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let found = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        events = found.prefix(6).map { event in
            EventItem(
                id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                title: event.title ?? "Sin título",
                start: event.startDate,
                isAllDay: event.isAllDay,
                joinURL: Self.meetingURL(in: event)
            )
        }
    }

    private static func meetingURL(in event: EKEvent) -> URL? {
        let hosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com", "webex.com"]
        var texts: [String] = []
        if let url = event.url?.absoluteString { texts.append(url) }
        if let location = event.location { texts.append(location) }
        if let notes = event.notes { texts.append(notes) }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        for text in texts {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                guard let url = match.url, let host = url.host?.lowercased() else { continue }
                if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return url }
            }
        }
        return nil
    }
}

// MARK: - Temporizador

@MainActor
final class CountdownTimer: ObservableObject {
    @Published var remaining = 25 * 60
    @Published var running = false

    private var ticker: Timer?

    var label: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    func set(minutes: Int) {
        pause()
        remaining = minutes * 60
    }

    func toggle() {
        running ? pause() : startTicking()
    }

    func pause() {
        ticker?.invalidate()
        ticker = nil
        running = false
    }

    private func startTicking() {
        guard remaining > 0 else { return }
        running = true
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func step() {
        remaining = max(0, remaining - 1)
        if remaining == 0 {
            pause()
            NSSound(named: "Glass")?.play()
        }
    }
}
