import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: BridgeModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechController()
    @State private var showSettings = false
    @AppStorage("voiceLaunch") private var voiceLaunch: Double = 0
    @AppStorage("textLaunch") private var textLaunch: Double = 0
    @AppStorage("speakReplies") private var speakReplies = true
    @AppStorage("privacyAccepted") private var privacyAccepted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("中文交给我").font(.largeTitle.bold())
                        Text("Siri 保持原来的语言。Bridge 听懂中文，帮你完成日常小事。")
                            .foregroundStyle(.secondary)
                    }
                    if !privacyAccepted {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("开始前").font(.headline)
                            Text("语音优先在设备识别；设备不支持时可能由 Apple 处理。点击「理解请求」后，文字及当前时区将发到你配置的服务和 OpenAI。录音不会发到 Bridge 服务。")
                            Button("我已了解，开始使用") { privacyAccepted = true }.buttonStyle(.borderedProminent)
                        }.padding().background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("例如：明天下午六点提醒我买牛奶", text: $model.input, axis: .vertical)
                            .lineLimit(3...7).textFieldStyle(.plain)
                            .disabled(model.busy || model.pending != nil || !privacyAccepted || speech.isRecording || speech.isStarting)
                        Divider()
                        HStack {
                            Button {
                                if speech.isRecording { speech.stop() }
                                else { Task { await speech.start() } }
                            } label: {
                                Label(speech.isRecording ? "停止录音" : "说中文", systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                            }.disabled(model.busy || model.pending != nil || !privacyAccepted || speech.isStarting)
                            Spacer()
                            Button("理解请求") { speech.stopPlayback(); model.submit() }
                                .buttonStyle(.borderedProminent)
                                .disabled(model.busy || model.pending != nil || speech.isRecording || speech.isStarting || !privacyAccepted || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if speech.isRecording { Text("正在听中文 · 最长 55 秒").font(.caption).foregroundStyle(.indigo) }
                        if let error = speech.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                    }.padding().background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: model.failed ? "exclamationmark.circle" : "bubble.left.and.bubble.right")
                            Text("Bridge").font(.headline)
                            if model.busy { ProgressView() }
                        }
                        Text(model.message).textSelection(.enabled).accessibilityAddTraits(.updatesFrequently)
                        if let item = model.pending {
                            Text(item.plan.summary()).font(.headline)
                            HStack {
                                Button("取消", role: .cancel) { model.cancel() }.buttonStyle(.bordered)
                                Button("确认执行") { Task { await model.confirm(id: item.id) } }
                                    .buttonStyle(.borderedProminent)
                            }.disabled(model.busy)
                        }
                    }.padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    Text("支持地图、音乐、微信 · 提醒事项 · iOS 26 一次性闹钟")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("录音停止后，可编辑文字再发送。侧边按钮仍唤起 Siri；可用英语说 “Talk to Bridge”，或将操作按钮／轻点背面绑定到「开始中文对话」。")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }
            .navigationTitle("Bridge").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("设置").disabled(model.busy || speech.isRecording || speech.isStarting)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onChange(of: speech.transcript) { _, text in model.input = text }
            .onChange(of: model.message) { _, text in
                if speakReplies && !model.busy && scenePhase == .active { speech.speak(text) }
            }
            .onChange(of: model.busy) { _, busy in
                if !busy && speakReplies && scenePhase == .active { speech.speak(model.message) }
            }
            .onChange(of: voiceLaunch) { _, _ in consumeLaunch() }
            .onChange(of: textLaunch) { _, _ in consumeLaunch() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { consumeLaunch() }
                else if phase == .background { speech.stop(); speech.stopPlayback() }
            }
            .onAppear { consumeLaunch() }
        }
    }
    private func consumeLaunch() {
        guard scenePhase == .active, !model.busy, model.pending == nil else { return }
        if textLaunch > 0 {
            let recent = Date().timeIntervalSince1970 - textLaunch < 60
            textLaunch = 0
            if recent { model.input = UserDefaults.standard.string(forKey: "incomingText") ?? "" }
            UserDefaults.standard.removeObject(forKey: "incomingText")
        }
        if voiceLaunch > 0 {
            let recent = Date().timeIntervalSince1970 - voiceLaunch < 60
            voiceLaunch = 0
            if recent && privacyAccepted { Task { await speech.start() } }
        }
    }
}
