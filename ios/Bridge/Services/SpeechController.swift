import AVFoundation
import Speech
import SwiftUI

@MainActor
final class SpeechController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isStarting = false
    @Published private(set) var transcript = ""
    @Published private(set) var errorMessage: String?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var timer: Task<Void, Never>?
    private var hasTap = false
    private var generation = UUID()
    private let speaker = AVSpeechSynthesizer()

    func start() async {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        stopPlayback()
        transcript = ""; errorMessage = nil
        let sessionID = UUID(); generation = sessionID
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == sessionID else { return }
        guard speechStatus == .authorized else { errorMessage = "请在系统设置中允许语音识别，或直接输入文字。"; return }
        let micAllowed = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard generation == sessionID else { return }
        guard micAllowed else { errorMessage = "请在系统设置中允许麦克风，或直接输入文字。"; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), recognizer.isAvailable else {
            errorMessage = "中文语音识别暂时不可用，请输入文字。"; return
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audio.setActive(true, options: .notifyOthersOnDeactivation)
            let buffer = SFSpeechAudioBufferRecognitionRequest()
            buffer.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { buffer.requiresOnDeviceRecognition = true }
            request = buffer
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw BridgeFailure.permission("没有可用的麦克风。") }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { audio, _ in buffer.append(audio) }
            hasTap = true
            recognition = recognizer.recognitionTask(with: buffer) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal ?? false
                let failed = error != nil
                Task { @MainActor in
                    guard let self, self.generation == sessionID else { return }
                    if let text { self.transcript = text }
                    if final || failed {
                        if failed && self.transcript.isEmpty { self.errorMessage = "没有识别到中文，请重试或输入文字。" }
                        self.stop()
                    }
                }
            }
            engine.prepare()
            try engine.start()
            isRecording = true
            timer = Task { [weak self] in
                try? await Task.sleep(for: .seconds(55))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch { stop(); errorMessage = error.localizedDescription }
    }
    func stop() {
        generation = UUID()
        timer?.cancel(); timer = nil
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio(); request = nil
        recognition?.cancel(); recognition = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func speak(_ text: String) {
        guard !isRecording, !isStarting else { return }
        speaker.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        speaker.speak(utterance)
    }
    func stopPlayback() { speaker.stopSpeaking(at: .immediate) }
}
