import Foundation
import IOKit.pwr_mgt

public final class PowerAssertion {
    private var assertionID: IOPMAssertionID = 0
    public private(set) var isHeld = false

    public init() {}

    deinit {
        release()
    }

    @discardableResult
    public func acquire() -> Bool {
        if isHeld { return true }

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            L10n.tr("power.assertion.reason") as CFString,
            &assertionID
        )
        isHeld = result == kIOReturnSuccess
        return isHeld
    }

    public func release() {
        guard isHeld else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isHeld = false
    }
}
