import SwiftUI

@main
struct CallDPMacApp: App {
    @StateObject private var runtime = AppRuntime()

    var body: some Scene {
        WindowGroup {
            ContentView(runtime: runtime)
        }
        .windowResizability(.contentSize)

        Window("Director", id: AppWindowID.director) {
            DirectorWindowContainer(runtime: runtime)
        }
        .windowResizability(.contentSize)

        Window("Camera Agent", id: AppWindowID.cameraAgent) {
            CameraAgentWindowContainer(runtime: runtime)
        }
        .windowResizability(.contentSize)
    }
}
