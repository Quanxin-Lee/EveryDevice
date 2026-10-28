import Combine
import EveryDeviceCore

final class PowerController: ObservableObject {
    @Published private(set) var isActive = false

    private let assertion = PowerAssertion()

    func set(_ enabled: Bool) {
        if enabled {
            isActive = assertion.acquire()
        } else {
            assertion.release()
            isActive = false
        }
    }
}
