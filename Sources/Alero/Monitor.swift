import AppKit
import Darwin
import SwiftUI

// MARK: - Datos

/// Un proceso tal como lo informa `ps`.
struct ProcessSample: Sendable {
    var pid: Int32
    var name: String
    var cpu: Double
    var memoryMB: Double
}

struct ResourceSnapshot: Sendable {
    var cpuPercent: Double
    var memoryUsedGB: Double?
    var top: [ProcessSample]
}

/// Un proceso listo para mostrarse en la lista.
struct ProcessRow: Identifiable {
    var pid: Int32
    var name: String
    var cpu: Double
    var memoryMB: Double
    var icon: NSImage?
    /// Solo las apps normales del usuario se pueden cerrar desde la lista.
    var isApp: Bool

    var id: Int32 { pid }
}

enum ProcessSort: Sendable {
    case cpu, memory
}

// MARK: - Servicio

/// Mide el uso de CPU y memoria y lista los procesos que más consumen.
/// Solo trabaja cuando se le pide: el controlador lo llama cada 2.5 s
/// y únicamente mientras la pestaña del monitor está abierta.
@MainActor
final class ResourceMonitor: ObservableObject {
    @Published var cpuPercent: Double = 0
    @Published var memoryUsedGB: Double = 0
    @Published var rows: [ProcessRow] = []
    @Published var sort: ProcessSort = .cpu
    @Published var loaded = false

    let memoryTotalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

    private let queue = DispatchQueue(label: "alero.monitor")
    private var busy = false

    func refresh() {
        guard !busy else { return }
        busy = true
        let sort = self.sort
        queue.async { [weak self] in
            let snapshot = ResourceMonitor.sample(sort: sort)
            Task { @MainActor in self?.apply(snapshot) }
        }
    }

    func setSort(_ newSort: ProcessSort) {
        guard sort != newSort else { return }
        sort = newSort
        refresh()
    }

    /// Pide a la app que se cierre de forma normal (puede mostrar "¿Guardar cambios?").
    func quit(_ row: ProcessRow) {
        guard row.isApp else { return }
        NSRunningApplication(processIdentifier: row.pid)?.terminate()
    }

    private func apply(_ snapshot: ResourceSnapshot?) {
        busy = false
        guard let snapshot else { return }
        cpuPercent = snapshot.cpuPercent
        if let used = snapshot.memoryUsedGB { memoryUsedGB = used }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        rows = snapshot.top.map { sample in
            let app = NSRunningApplication(processIdentifier: sample.pid)
            return ProcessRow(
                pid: sample.pid,
                name: app?.localizedName ?? sample.name,
                cpu: sample.cpu,
                memoryMB: sample.memoryMB,
                icon: app?.icon,
                isApp: app?.activationPolicy == .regular && sample.pid != ownPID
            )
        }
        loaded = true
    }

    // MARK: Medición (fuera del hilo principal)

    nonisolated static func sample(sort: ProcessSort) -> ResourceSnapshot? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        // -A: todos los procesos. -c: solo el nombre del ejecutable.
        // Cada columna con "=" para que no imprima encabezado.
        process.arguments = ["-A", "-c", "-o", "pid=", "-o", "pcpu=", "-o", "rss=", "-o", "comm="]
        // Fuerza el punto decimal sin importar el idioma del sistema.
        process.environment = ["LC_ALL": "C"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        var all: [ProcessSample] = []
        var totalCPU = 0.0
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1].replacingOccurrences(of: ",", with: ".")),
                  let rssKB = Double(parts[2]) else { continue }
            totalCPU += cpu
            all.append(
                ProcessSample(
                    pid: pid,
                    name: parts[3].trimmingCharacters(in: .whitespaces),
                    cpu: cpu,
                    memoryMB: rssKB / 1024
                )
            )
        }

        switch sort {
        case .cpu: all.sort { $0.cpu > $1.cpu }
        case .memory: all.sort { $0.memoryMB > $1.memoryMB }
        }

        // `ps` informa el % por núcleo; se divide entre los núcleos para el total del equipo.
        let cores = Double(max(ProcessInfo.processInfo.activeProcessorCount, 1))
        return ResourceSnapshot(
            cpuPercent: min(totalCPU / cores, 100),
            memoryUsedGB: usedMemoryGB(),
            top: Array(all.prefix(8))
        )
    }

    /// Memoria en uso: apps + reservada por el sistema + comprimida.
    nonisolated static func usedMemoryGB() -> Double? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let pages = Double(stats.internal_page_count) - Double(stats.purgeable_count)
            + Double(stats.wire_count) + Double(stats.compressor_page_count)
        return max(pages, 0) * Double(pageSize) / 1_073_741_824
    }
}

// MARK: - Vista

struct MonitorView: View {
    @EnvironmentObject var monitor: ResourceMonitor

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                gauge(
                    title: "CPU",
                    value: String(format: "%.0f%%", monitor.cpuPercent),
                    fraction: monitor.cpuPercent / 100
                )
                gauge(
                    title: "Memoria",
                    value: String(format: "%.1f de %.0f GB", monitor.memoryUsedGB, monitor.memoryTotalGB),
                    fraction: monitor.memoryTotalGB > 0 ? monitor.memoryUsedGB / monitor.memoryTotalGB : 0
                )
            }
            .frame(width: 150)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text("Procesos que más consumen")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                    sortButton("CPU", .cpu)
                    sortButton("Memoria", .memory)
                }
                if monitor.rows.isEmpty {
                    EmptyHint(
                        icon: "cpu",
                        text: monitor.loaded ? "No se pudo leer la lista de procesos." : "Midiendo…"
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 3) {
                            ForEach(monitor.rows) { row in
                                processRow(row)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { monitor.refresh() }
    }

    private func gauge(title: String, value: String, fraction: Double) -> some View {
        let clamped = min(max(fraction, 0), 1)
        let color: Color = clamped > 0.85 ? .red : (clamped > 0.6 ? .orange : .green)
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(color).frame(width: max(4, geometry.size.width * CGFloat(clamped)))
                }
            }
            .frame(height: 6)
        }
    }

    private func sortButton(_ title: String, _ sort: ProcessSort) -> some View {
        Button(title) { monitor.setSort(sort) }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(monitor.sort == sort ? 0.22 : 0.08)))
            .help("Ordenar por \(title)")
    }

    private func processRow(_ row: ProcessRow) -> some View {
        HStack(spacing: 8) {
            Group {
                if let icon = row.icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .frame(width: 16, height: 16)

            Text(row.name)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer(minLength: 4)

            Text(String(format: "%.1f%%", row.cpu))
                .frame(width: 54, alignment: .trailing)
            Text(Self.memoryLabel(row.memoryMB))
                .frame(width: 62, alignment: .trailing)

            Button {
                monitor.quit(row)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .help("Cerrar \(row.name)")
            .opacity(row.isApp ? 1 : 0)
            .disabled(!row.isApp)
        }
        .font(.system(size: 11, weight: .medium))
        .monospacedDigit()
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.07)))
    }

    private static func memoryLabel(_ megabytes: Double) -> String {
        megabytes >= 1024
            ? String(format: "%.1f GB", megabytes / 1024)
            : String(format: "%.0f MB", megabytes)
    }
}
