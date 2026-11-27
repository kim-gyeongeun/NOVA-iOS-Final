import SwiftUI
import Speech
import AVFoundation

@MainActor final class VoiceRecorder: ObservableObject {
    @Published var text = ""
    @Published var recording = false
    @Published var error: String?
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() async {
        let permitted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status == .authorized) }
        }
        guard permitted else { error = "음성 인식 권한이 필요합니다."; return }
        let mic = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in continuation.resume(returning: allowed) }
        }
        guard mic else { error = "마이크 권한이 필요합니다."; return }
        do {
            stop()
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            let newRequest = SFSpeechAudioBufferRecognitionRequest()
            newRequest.shouldReportPartialResults = true
            request = newRequest
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in newRequest.append(buffer) }
            engine.prepare(); try engine.start()
            recording = true
            task = recognizer?.recognitionTask(with: newRequest) { [weak self] result, failure in
                Task { @MainActor in
                    if let result { self?.text = result.bestTranscription.formattedString }
                    if let failure { self?.error = failure.localizedDescription; self?.stop() }
                }
            }
        } catch { self.error = error.localizedDescription; stop() }
    }
    func stop() {
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        request?.endAudio(); task?.cancel(); task = nil; request = nil
        recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct VoiceInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = VoiceRecorder()
    let onCommit: (String) -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: recorder.recording ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 75)).foregroundStyle(NovaStyle.cyan)
                Text(recorder.recording ? "듣고 있어요..." : "음성 입력").font(.title2.bold())
                Text(recorder.text.isEmpty ? "버튼을 눌러 한국어로 말해보세요." : recorder.text)
                    .foregroundStyle(recorder.text.isEmpty ? NovaStyle.muted : .white)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                    .padding().background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 17))
                if let error = recorder.error { ErrorBanner(text: error) }
                PrimaryAction(recorder.recording ? "녹음 중지" : "녹음 시작", icon: recorder.recording ? "stop.fill" : "mic.fill") {
                    if recorder.recording { recorder.stop() } else { Task { await recorder.start() } }
                }
                Button("텍스트 적용") { recorder.stop(); onCommit(recorder.text); dismiss() }
                    .buttonStyle(.borderedProminent).disabled(recorder.text.isEmpty)
                Spacer()
            }.padding(22)
                .navigationTitle("Voice")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
                .novaScreen()
        }.onDisappear { recorder.stop() }.preferredColorScheme(.light)
    }
}
