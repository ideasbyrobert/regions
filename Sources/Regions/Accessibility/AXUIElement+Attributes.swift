import ApplicationServices
import CoreGraphics
import Foundation

extension AXUIElement
{
    func copiedElement(for attribute: CFString) -> AXUIElement?
    {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(self, attribute, &value) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else
        {
            return nil
        }
        return (value as! AXUIElement)
    }

    func copiedElements(for attribute: CFString) -> [AXUIElement]?
    {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(self, attribute, &value) == .success,
            let value,
            CFGetTypeID(value) == CFArrayGetTypeID()
        else
        {
            return nil
        }
        return value as? [AXUIElement]
    }

    func copiedString(for attribute: CFString) -> String?
    {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute, &value) == .success
        else
        {
            return nil
        }
        return value as? String
    }

    func copiedBoolean(for attribute: CFString) -> Bool?
    {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute, &value) == .success
        else
        {
            return nil
        }
        return value as? Bool
    }

    func copiedPoint(for attribute: CFString) -> CGPoint?
    {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(self, attribute, &value) == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else
        {
            return nil
        }
        let axValue = (value as! AXValue)
        guard AXValueGetType(axValue) == .cgPoint
        else
        {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point)
        else
        {
            return nil
        }
        return point
    }

    func copiedSize(for attribute: CFString) -> CGSize?
    {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(self, attribute, &value) == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else
        {
            return nil
        }
        let axValue = (value as! AXValue)
        guard AXValueGetType(axValue) == .cgSize
        else
        {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size)
        else
        {
            return nil
        }
        return size
    }

    func isAttributeSettable(_ attribute: CFString) -> Bool
    {
        var settable = DarwinBoolean(false)
        guard
            AXUIElementIsAttributeSettable(self, attribute, &settable)
                == .success
        else
        {
            return false
        }
        return settable.boolValue
    }

    func setPoint(_ point: CGPoint, for attribute: CFString) -> AXError
    {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point)
        else
        {
            return .illegalArgument
        }
        return AXUIElementSetAttributeValue(self, attribute, value)
    }

    func setSize(_ size: CGSize, for attribute: CFString) -> AXError
    {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size)
        else
        {
            return .illegalArgument
        }
        return AXUIElementSetAttributeValue(self, attribute, value)
    }

    func setBoolean(_ boolean: Bool, for attribute: CFString) -> AXError
    {
        AXUIElementSetAttributeValue(
            self,
            attribute,
            boolean ? kCFBooleanTrue : kCFBooleanFalse
        )
    }

    func setElement(_ element: AXUIElement, for attribute: CFString) -> AXError
    {
        AXUIElementSetAttributeValue(self, attribute, element)
    }

    func perform(_ action: CFString) -> AXError
    {
        AXUIElementPerformAction(self, action)
    }
}
