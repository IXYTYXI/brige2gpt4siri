import SwiftUI

@MainActor
final class BridgeModel: ObservableObject {
    @Published var input = ""
    @Published private(set) var message = "你好，直接用中文告诉我你想做什么。"
    @Published private(set) var busy = false
    @Published private(set) var pending: PendingAction?
    @Published private(set) var failed = false
    private var gate = ConfirmationGate()
    private let executor = ActionExecutor()
    private var planning: Task<Void, Never>?
    private var generation = UUID()

    func submit() {
        guard !busy else { return }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 2000 else { message = "请输入 1–2000 个字符。"; failed = true; return }
        gate.cancel(); pending = nil; failed = false; busy = true
        message = "正在理解…"
        let id = UUID(); generation = id
        planning = Task {
            defer { if generation == id { busy = false; planning = nil } }
            do {
                let plan = try await BridgeClient().plan(text: text, supportsAlarm: ActionExecutor.supportsAlarm)
                guard !Task.isCancelled, generation == id else { return }
                if plan.requiresConfirmation {
                    gate.stage(plan); pending = gate.pending
                    message = "请核对下面的操作。"
                } else { message = plan.replyZH }
            } catch {
                guard !Task.isCancelled, generation == id else { return }
                failed = true; message = error.localizedDescription
            }
        }
    }
    func cancel() {
        guard planning != nil || !busy else { return } // In-flight system writes cannot be undone here.
        generation = UUID(); planning?.cancel(); planning = nil; busy = false
        gate.cancel(); pending = nil; failed = false; message = "已取消，未执行操作。"
    }
    func confirm(id: UUID) async {
        guard !busy else { return }
        busy = true; failed = false
        defer { busy = false }
        do {
            let item = try gate.consume(id: id, supportsAlarm: ActionExecutor.supportsAlarm)
            pending = nil
            message = "正在执行…"
            message = try await executor.execute(item)
        } catch { pending = nil; failed = true; message = error.localizedDescription }
    }
}
