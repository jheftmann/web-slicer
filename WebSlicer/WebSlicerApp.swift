import SwiftUI

@main
struct WebSlicerApp: App {
    @State private var model = SliceModel()

    var body: some Scene {
        Window("Web Slicer", id: "main") {
            ContentView()
                .environment(model)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { model.isPickingFiles = true }
                    .keyboardShortcut("o")
            }
        }
    }
}
