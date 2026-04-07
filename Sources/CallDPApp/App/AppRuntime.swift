import Combine
import Foundation

@MainActor
final class AppRuntime: ObservableObject {
    let loopbackTransport = LoopbackRemoteCommandTransport()
    private var cancellables: Set<AnyCancellable> = []

    init() {
        loopbackTransport.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
