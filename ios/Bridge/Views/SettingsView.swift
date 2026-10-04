import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var endpoint = SettingsStore.endpoint
    @State private var token = SettingsStore.token()
    @State private var error: String?
    @AppStorage("speakReplies") private var speakReplies = true
    var body: some View {
        NavigationStack {
            Form {
                Section("连接你的服务") {
                    TextField("https://bridge.example.com", text: $endpoint)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("服务令牌（不是 OpenAI API Key）", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("OpenAI API Key 只放在服务端。服务令牌保存在这台 iPhone 的钥匙串中。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("回复") { Toggle("朗读中文回复", isOn: $speakReplies) }
                if #available(iOS 26.0, *) {
                    Section("闹钟") { NavigationLink("查看或取消 Bridge 闹钟") { AlarmsView() } }
                }
                Section("权限") {
                    Text("麦克风、语音识别、提醒事项和闹钟权限，只在使用相关功能时请求。")
                    Text("提醒和闹钟只有确认并保存成功后才会报告成功。Bridge 闹钟由本 App 管理，不是时钟 App 的闹钟。")
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("清除连接设置", role: .destructive) { SettingsStore.clear(); endpoint = ""; token = "" }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try SettingsStore.save(endpoint: endpoint, token: token); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }
                }
            }
        }
    }
}
