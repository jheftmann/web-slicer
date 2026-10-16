import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(SliceModel.self) private var model
    @AppStorage("maxWidth") private var maxWidth = PixelSetting.defaultValue
    @AppStorage("sliceHeight") private var sliceHeight = PixelSetting.defaultValue
    @State private var isTargeted = false

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            Button { model.isPickingFiles = true } label: { dropZone }
                .buttonStyle(.plain)
                .dropDestination(for: URL.self) { urls, _ in
                    slice(urls)
                    return true
                } isTargeted: { isTargeted = $0 }

            Divider()

            HStack(spacing: 20) {
                PixelField(title: "Width (scale)", value: $maxWidth)
                PixelField(title: "Height (slice)", value: $sliceHeight)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
        }
        .frame(width: 460)
        .fileImporter(isPresented: $model.isPickingFiles, allowedContentTypes: [.image],
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { slice(urls) }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 120, height: 120)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [12, 7]))
                        .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                }

            if model.isWorking {
                ProgressView().controlSize(.small)
            } else if model.results.isEmpty {
                Text("Drop your images here")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(model.results, id: \.self) { Text($0) }
                }
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(.vertical, 24)
        .contentShape(Rectangle())
    }

    private func slice(_ urls: [URL]) {
        model.process(urls, maxWidth: maxWidth, sliceHeight: sliceHeight)
    }
}

/// A pixel-count field. The value tracks every keystroke (sanitized) so a drop mid-edit
/// uses what's typed; the text itself is normalized on Return or when focus leaves.
private struct PixelField: View {
    let title: String
    @Binding var value: Int
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            TextField(title, text: $text)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .focused($isFocused)
                .onSubmit(commit)
            Text("px").foregroundStyle(.secondary)
        }
        .onAppear { text = String(value) }
        .onChange(of: text) { value = PixelSetting.sanitize(text) }
        .onChange(of: isFocused) { if !isFocused { commit() } }
    }

    private func commit() {
        text = String(value)
    }
}
