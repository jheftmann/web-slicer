import AppKit
import Observation

/// Runs slicing off the main thread and holds what the window shows afterwards.
@MainActor @Observable
final class SliceModel {
    var isPickingFiles = false
    var isWorking = false
    /// One line per dropped file: its readout, an error, or "Skipped: …".
    var results: [String] = []

    func process(_ urls: [URL], maxWidth: Int, sliceHeight: Int) {
        guard !urls.isEmpty, !isWorking else { return }
        isWorking = true
        Task {
            let (lines, folders) = await Task.detached(priority: .userInitiated) {
                Self.run(urls, maxWidth: maxWidth, sliceHeight: sliceHeight)
            }.value
            results = lines
            isWorking = false
            if !folders.isEmpty {
                NSWorkspace.shared.activateFileViewerSelecting(folders)
            }
        }
    }

    private nonisolated static func run(_ urls: [URL], maxWidth: Int, sliceHeight: Int) -> ([String], [URL]) {
        var lines: [String] = []
        var folders: [URL] = []
        let label = urls.count > 1
        for url in urls {
            let name = url.lastPathComponent
            guard Slicer.isImage(url) else {
                lines.append("Skipped: \(name)")
                continue
            }
            do {
                let output = try Slicer.slice(url, maxWidth: maxWidth, sliceHeight: sliceHeight)
                folders.append(output.folder)
                lines.append(label ? "\(name): \(output.plan.summary)" : output.plan.summary)
            } catch {
                lines.append(error.localizedDescription)
            }
        }
        return (lines, folders)
    }
}
