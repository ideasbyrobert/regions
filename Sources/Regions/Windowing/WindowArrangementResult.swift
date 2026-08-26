import Foundation

enum WindowArrangementResult: Equatable, Sendable
{
    case arranged(windowCount: Int, usedBestEffort: Bool, terminalSized: Bool)
    case restored(windowCount: Int, usedBestEffort: Bool)
    case failed(WindowArrangementFailure)
}
