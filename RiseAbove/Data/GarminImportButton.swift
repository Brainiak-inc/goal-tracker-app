import SwiftUI
import UniformTypeIdentifiers

struct GarminImportButton: View {
    @Environment(ActivityLibrary.self) private var library
    @State private var isPicking = false
    @State private var summary: ImportSummary?
    @State private var failed = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            Label("Import Garmin CSV", systemImage: "square.and.arrow.down")
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result, let text = read(url) else {
                failed = true
                return
            }
            summary = library.importGarminCSV(text)
        }
        .alert("Import finished", isPresented: Binding(get: { summary != nil }, set: { if !$0 { summary = nil } }), presenting: summary) { _ in
            Button("OK") {}
        } message: { summary in
            Text("Added: \(summary.added), updated: \(summary.updated), skipped: \(summary.skipped)")
        }
        .alert("Couldn't read the file", isPresented: $failed) {
            Button("OK") {}
        } message: {
            Text("Choose a CSV file exported from Garmin Connect: Activities → Export CSV.")
        }
    }

    private func read(_ url: URL) -> String? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
