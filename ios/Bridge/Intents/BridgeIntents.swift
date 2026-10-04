import AppIntents
import Foundation

struct OpenChineseAssistantIntent: AppIntent {
    static var title: LocalizedStringResource = "开始中文对话"
    static var description = IntentDescription("打开 Bridge 并开始中文语音输入，不更改 Siri 的语言。")
    static var openAppWhenRun: Bool = true
    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "voiceLaunch")
        return .result()
    }
}

struct SendChineseTextIntent: AppIntent {
    static var title: LocalizedStringResource = "输入中文请求"
    static var description = IntentDescription("将快捷指令中的中文文本交给 Bridge，打开 App 后理解并确认。")
    static var openAppWhenRun: Bool = true
    @Parameter(title: "中文请求") var text: String
    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(String(text.prefix(2000)), forKey: "incomingText")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "textLaunch")
        return .result()
    }
}

struct BridgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenChineseAssistantIntent(), phrases: [
            "Talk to \(.applicationName)", "Start \(.applicationName)", "打开\(.applicationName)"
        ], shortTitle: "开始中文对话", systemImageName: "mic.fill")
        AppShortcut(intent: SendChineseTextIntent(), phrases: ["Ask \(.applicationName)"],
                    shortTitle: "输入中文请求", systemImageName: "text.bubble.fill")
    }
}
