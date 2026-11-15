import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Raíz

struct NotchRootView: View {
    @EnvironmentObject var state: NotchState
    @EnvironmentObject var tray: FileTray
    @EnvironmentObject var music: MusicService
    @EnvironmentObject var battery: BatteryService
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var hud: HUDService
    @State private var dropTargeted = false

    /// Qué se muestra a los lados del notch cuando el panel está cerrado.
    private var activity: CompactActivity {
        if hud.kind == .volume { return .volume }
        if hud.kind == .brightness { return .brightness }
        if settings.showChargeNotice, battery.showChargeNotice { return .charging }
        if settings.showMediaIndicator, music.track?.isPlaying == true { return .media }
        return .none
    }

    private var currentSize: CGSize {
        if state.expanded { return state.fullSize }
        let wings: CGFloat = activity == .none ? 0 : CompactView.wing * 2
        return CGSize(width: state.notchSize.width + wings, height: state.notchSize.height)
    }

    private var shape: UnevenRoundedRectangle {
        let radius: CGFloat = state.expanded ? 24 : 10
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            shape.fill(Color.black)
            if state.expanded {
                ExpandedView()
                    .transition(.opacity)
            } else if activity != .none {
                CompactView(activity: activity)
                    .transition(.opacity)
            }
        }
        .frame(width: currentSize.width, height: currentSize.height)
        .clipShape(shape)
        .overlay(
            shape.stroke(Color.accentColor.opacity(dropTargeted ? 0.9 : 0), lineWidth: 2)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            state.tab = .files
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in tray.add(url) }
                }
            }
            return true
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentSize)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Vista compacta (panel cerrado)

enum CompactActivity: Equatable {
    case none, charging, media, volume, brightness
}

/// Indicadores a izquierda y derecha del notch: batería cargando o audio sonando.
struct CompactView: View {
    static let wing: CGFloat = 52

    @EnvironmentObject var state: NotchState
    @EnvironmentObject var music: MusicService
    @EnvironmentObject var battery: BatteryService
    @EnvironmentObject var hud: HUDService
    @EnvironmentObject var settings: AppSettings
    let activity: CompactActivity

    /// Respeta el ajuste de la app y "Reducir movimiento" de macOS.
    private var animateWave: Bool {
        settings.animateIndicator && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Nivel de 0 a 1 mostrado como porcentaje, por ejemplo "65%".
    private func percentLabel(_ value: Double) -> some View {
        Text("\(Int((min(max(value, 0), 1) * 100).rounded()))%")
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
    }

    var body: some View {
        HStack(spacing: 0) {
            left.frame(width: Self.wing)
            Spacer(minLength: 0)
            right.frame(width: Self.wing)
        }
        .frame(height: state.notchSize.height)
        .foregroundStyle(Color.white)
    }

    @ViewBuilder
    private var left: some View {
        switch activity {
        case .charging:
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.green)
        case .media:
            if let artwork = music.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
            }
        case .volume:
            Image(systemName: hud.muted || hud.value <= 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 12, weight: .semibold))
        case .brightness:
            Image(systemName: "sun.max.fill")
                .font(.system(size: 12, weight: .semibold))
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var right: some View {
        switch activity {
        case .charging:
            Text("\(battery.level ?? 0)%")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.green)
        case .media:
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: animateWave)
        case .volume:
            percentLabel(hud.muted ? 0 : hud.value)
        case .brightness:
            percentLabel(hud.value)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Panel expandido

struct ExpandedView: View {
    @EnvironmentObject var state: NotchState
    @EnvironmentObject var countdown: CountdownTimer
    @EnvironmentObject var battery: BatteryService
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var music: MusicService

    /// Pestaña que se muestra: la elegida, o la primera visible si esa está oculta.
    private var activeTab: AleroTab {
        settings.activeTab(for: state.tab)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Franja a la altura del notch: pestañas a la izquierda, estado a la derecha.
            HStack(spacing: 0) {
                HStack(spacing: 3) {
                    ForEach(settings.visibleTabs) { tab in
                        Button {
                            state.tab = tab
                        } label: {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 27, height: 22)
                                .background(
                                    Capsule().fill(Color.white.opacity(activeTab == tab ? 0.18 : 0))
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(activeTab == tab ? Color.white : Color.white.opacity(0.55))
                        .help(tab.title)
                    }
                }
                .padding(.leading, 14)

                Spacer(minLength: state.notchSize.width)

                HStack(spacing: 10) {
                    if countdown.running {
                        Label(countdown.label, systemImage: "timer")
                            .monospacedDigit()
                    } else {
                        Text(Date(), format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    }
                    if let level = battery.level {
                        Label("\(level)%", systemImage: battery.pluggedIn ? "bolt.fill" : "battery.100")
                            .monospacedDigit()
                            .foregroundStyle(battery.pluggedIn ? Color.green : Color.white.opacity(0.7))
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))
                .padding(.trailing, 16)
            }
            .frame(height: state.notchSize.height)

            Group {
                switch activeTab {
                case .music: MusicView()
                case .files: FilesView()
                case .calendar: CalendarView()
                case .notes: NotesView()
                case .clipboard: ClipboardView()
                case .monitor: MonitorView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                // Fondo teñido con el color de la carátula.
                if activeTab == .music, let tint = music.tint {
                    LinearGradient(
                        colors: [tint.opacity(0.45), Color.clear],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                }
            }
        }
        .foregroundStyle(Color.white)
    }
}

/// Mensaje centrado para estados vacíos.
struct EmptyHint: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26))
            Text(text)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.white.opacity(0.55))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Música

struct MusicView: View {
    @EnvironmentObject var music: MusicService

    var body: some View {
        if let track = music.track {
            HStack(spacing: 16) {
                artwork(for: track)
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineLimit(1)
                    Text(track.playerName)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.4))
                    if let duration = track.duration, duration > 0 {
                        ProgressRow(duration: duration)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 18) {
                    control("backward.fill", size: 18, help: tr("Anterior", "Previous")) { music.previous() }
                    control(track.isPlaying ? "pause.fill" : "play.fill", size: 28,
                            help: track.isPlaying ? tr("Pausar", "Pause") : tr("Reproducir", "Play")) { music.playPause() }
                    control("forward.fill", size: 18, help: tr("Siguiente", "Next")) { music.next() }
                }
            }
        } else {
            EmptyHint(
                icon: "music.note",
                text: music.usesSystemMedia
                    ? tr("No hay nada sonando.\nReproduce música o un video en cualquier app.", "Nothing is playing.\nPlay music or a video in any app.")
                    : tr("No hay nada sonando.\nAbre Spotify o Música y reproduce una canción.", "Nothing is playing.\nOpen Spotify or Music and play a song.")
            )
        }
    }

    @ViewBuilder
    private func artwork(for track: TrackInfo) -> some View {
        if let image = music.artwork {
            Image(nsImage: image).resizable().scaledToFill()
        } else if let url = track.artworkURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.1)
            Image(systemName: "music.note")
                .font(.system(size: 34))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }

    private func control(_ icon: String, size: CGFloat, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Archivos

struct FilesView: View {
    @EnvironmentObject var tray: FileTray

    var body: some View {
        if tray.items.isEmpty {
            EmptyHint(icon: "tray.and.arrow.down", text: tr("Arrastra archivos al notch para tenerlos a la mano.", "Drag files onto the notch to keep them handy."))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tr("\(tray.items.count) en la bandeja", "\(tray.items.count) in the tray"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                    Button(tr("Enviar por AirDrop", "Send with AirDrop")) { tray.airdrop() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .padding(.trailing, 10)
                    Button(tr("Vaciar bandeja", "Empty tray")) { tray.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tray.items, id: \.self) { url in
                            FileTile(url: url)
                        }
                    }
                }
            }
        }
    }
}

struct FileTile: View {
    @EnvironmentObject var tray: FileTray
    let url: URL

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 56, height: 56)
            Text(url.lastPathComponent)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 84)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)))
        .contentShape(Rectangle())
        .onTapGesture { NSWorkspace.shared.open(url) }
        .onDrag { NSItemProvider(object: url as NSURL) }
        .contextMenu {
            Button(tr("Abrir", "Open")) { NSWorkspace.shared.open(url) }
            Button(tr("Mostrar en Finder", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Divider()
            Button(tr("Quitar de la bandeja", "Remove from tray")) { tray.remove(url) }
        }
        .help(url.path)
    }
}

// MARK: - Calendario

struct CalendarView: View {
    @EnvironmentObject var calendar: CalendarService

    var body: some View {
        if calendar.denied {
            EmptyHint(
                icon: "calendar.badge.exclamationmark",
                text: tr("Alero no tiene acceso al calendario.\nActívalo en Ajustes del Sistema > Privacidad y seguridad > Calendarios.", "Alero doesn't have access to your calendar.\nTurn it on in System Settings > Privacy & Security > Calendars.")
            )
        } else if calendar.events.isEmpty {
            EmptyHint(icon: "calendar", text: tr("No tienes eventos para hoy ni mañana.", "No events today or tomorrow."))
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(calendar.events) { event in
                        HStack(spacing: 12) {
                            Text(timeLabel(for: event))
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(Color.white.opacity(0.6))
                                .frame(width: 120, alignment: .leading)
                            Text(event.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if let url = event.joinURL {
                                Button(tr("Unirse", "Join")) { NSWorkspace.shared.open(url) }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.accentColor))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.08))
                        )
                    }
                }
            }
        }
    }

    private func timeLabel(for event: EventItem) -> String {
        let day = Calendar.current.isDateInToday(event.start) ? tr("Hoy", "Today") : tr("Mañana", "Tomorrow")
        if event.isAllDay { return tr("\(day), todo el día", "\(day), all day") }
        return "\(day), \(event.start.formatted(date: .omitted, time: .shortened))"
    }
}

// MARK: - Notas y temporizador

struct NotesView: View {
    @EnvironmentObject var countdown: CountdownTimer
    @AppStorage("alero.note") private var note = ""

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                if note.isEmpty {
                    Text(tr("Escribe una nota rápida", "Write a quick note"))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $note)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }

            VStack(spacing: 10) {
                Text(countdown.label)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 6) {
                    ForEach([5, 15, 25], id: \.self) { minutes in
                        Button("\(minutes) min") { countdown.set(minutes: minutes) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                }

                Button {
                    countdown.toggle()
                } label: {
                    Label(countdown.running ? tr("Pausar", "Pause") : tr("Iniciar", "Start"),
                          systemImage: countdown.running ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(width: 180)
        }
    }
}
