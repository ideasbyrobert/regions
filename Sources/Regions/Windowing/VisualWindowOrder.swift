import Foundation

struct VisualWindowOrder: Sendable
{
    func ordered(_ windows: [ManagedWindowSnapshot]) -> [ManagedWindowSnapshot]
    {
        windows.enumerated().sorted
        {
            first, second in
            if first.element.frame.maxY != second.element.frame.maxY
            {
                return first.element.frame.maxY > second.element.frame.maxY
            }
            if first.element.frame.minX != second.element.frame.minX
            {
                return first.element.frame.minX < second.element.frame.minX
            }
            return first.offset < second.offset
        }
        .map(\.element)
    }
}
