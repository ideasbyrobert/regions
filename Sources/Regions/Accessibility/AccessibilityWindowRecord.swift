import ApplicationServices
import Foundation

final class AccessibilityWindowRecord
{
    let processIdentifier: pid_t
    let element: AXUIElement

    init(processIdentifier: pid_t, element: AXUIElement)
    {
        self.processIdentifier = processIdentifier
        self.element = element
    }
}
