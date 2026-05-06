import SwiftUI

struct HunkyCommandActions {
    let addFiles: () -> Void
    let chooseOutput: () -> Void
    let start: () -> Void
    let stop: () -> Void
    let clearFinished: () -> Void
    let retryFailed: () -> Void
    let canStart: Bool
    let canStop: Bool
    let canClearFinished: Bool
    let canRetryFailed: Bool
}

private struct HunkyCommandActionsKey: FocusedValueKey {
    typealias Value = HunkyCommandActions
}

extension FocusedValues {
    var hunkyCommands: HunkyCommandActions? {
        get { self[HunkyCommandActionsKey.self] }
        set { self[HunkyCommandActionsKey.self] = newValue }
    }
}

struct HunkyCommands: Commands {
    @FocusedValue(\.hunkyCommands) private var actions

    var body: some Commands {
        CommandMenu("Queue") {
            Button("Add Files or Folders...") {
                actions?.addFiles()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(actions == nil)

            Button("Choose Output Folder...") {
                actions?.chooseOutput()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(actions == nil)

            Divider()

            Button("Start Queue") {
                actions?.start()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(actions?.canStart != true)

            Button("Stop Queue") {
                actions?.stop()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(actions?.canStop != true)

            Button("Retry Failed") {
                actions?.retryFailed()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(actions?.canRetryFailed != true)

            Button("Clear Finished") {
                actions?.clearFinished()
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .disabled(actions?.canClearFinished != true)
        }
    }
}
