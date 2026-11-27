import SwiftUI

struct SettingsView: View {
    @AppStorage("demoMode") private var demoMode = true
    @AppStorage("serverURL") private var serverURL = "http://127.0.0.1:8765"
    @State private var status: String?
    @State private var checking = false
    @State private var checkingProvider: AIProvider = .openai
    @State private var modelTestResult: String?
    @State private var testingModel = false
    var body: some View {
        Form {
            Section("모드 선택") {
                Toggle("데모 모드", isOn: $demoMode)
                Text(demoMode ? "현재 모든 답변은 미리 정의된 예시입니다. 실제 AI 호출을 하지 않습니다." : "실제 AI 모드: 백엔드 서버와 API 키가 필요합니다. 모델 호출 요금이 발생할 수 있습니다.")
                    .font(.caption).foregroundStyle(demoMode ? .orange : NovaStyle.cyan)
            }
            Section("백엔드 연결") {
                TextField("서버 주소", text: $serverURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.URL)
                Text("시뮬레이터: http://127.0.0.1:8765\n실제 아이폰: http://맥의로컬IP:8765\n같은 Wi-Fi에 연결되어야 합니다.")
                    .font(.caption).foregroundStyle(NovaStyle.muted)
                Button {
                    checking = true; status = nil
                    Task {
                        do {
                            let response = try await AIService().health()
                            let active = response.providers.filter(\.value).map(\.key).sorted().joined(separator: ", ")
                            status = "서버 연결됨 · API 준비: \(active.isEmpty ? "없음" : active)"
                        } catch { status = "연결 실패: \(error.localizedDescription)" }
                        checking = false
                    }
                } label: { HStack { Label("서버 연결 확인", systemImage: "network"); if checking { ProgressView() } } }
                if let status { Text(status).font(.caption).foregroundStyle(NovaStyle.cyan) }
                Text("서버 연결 확인은 API 키의 존재만 확인합니다. 실제 모델이 응답하는지는 아래 테스트로 확인하세요.")
                    .font(.caption).foregroundStyle(NovaStyle.muted)
            }
            Section("AI 연결") {
                NavigationLink {
                    ConnectionCenterView()
                } label: {
                    Label("AI 연결 센터 · GPT / Claude / Gemini", systemImage: "server.rack")
                }
                Text("모델별 키 상태, 설정된 모델 ID, 실제 API 응답까지 한 화면에서 확인할 수 있습니다.")
                    .font(.caption).foregroundStyle(NovaStyle.muted)
            }
            Section("AI 실제 연결 테스트") {
                Picker("테스트할 AI", selection: $checkingProvider) {
                    ForEach(AIProvider.allCases) { provider in Text(provider.title).tag(provider) }
                }
                Button {
                    modelTestResult = nil
                    testingModel = true
                    let provider = checkingProvider
                    Task {
                        do {
                            let answer = try await AIService().ask(provider, message: "연결 테스트입니다. 실제 모델이라면 'NOVA 연결 성공' 문구와 간단한 인사말을 한 문장으로 답해주세요.")
                            modelTestResult = "\(provider.title) 실제 API 응답: \(String(answer.prefix(400)))"
                        } catch { modelTestResult = "연결 테스트 실패: \(error.localizedDescription)" }
                        testingModel = false
                    }
                } label: {
                    HStack {
                        Label("모델 응답 테스트 (API 호출)", systemImage: "checkmark.shield")
                        if testingModel { ProgressView() }
                    }
                }.disabled(demoMode || testingModel)
                if demoMode { Text("실제 테스트하려면 데모 모드를 OFF로 변경하세요.").font(.caption).foregroundStyle(.orange) }
                if let modelTestResult { Text(modelTestResult).font(.caption).textSelection(.enabled) }
                Text("테스트 시 API 사용 요금이 발생할 수 있습니다. 모델이 응답하면 실제 호출이 작동하는 것입니다.")
                    .font(.caption).foregroundStyle(NovaStyle.muted)
            }
            Section("안내") {
                Label("API 키는 아이폰이 아닌 백엔드의 .env에 보관합니다.", systemImage: "lock.shield")
                Label("AI의 응답은 실수할 수 있습니다. 중요한 내용은 별도 확인하세요.", systemImage: "checkmark.shield")
                Label("기기 저장 데이터는 앱 삭제 시 함께 삭제될 수 있습니다.", systemImage: "externaldrive")
                Text("NOVA · AI Workspace · 디자인 리파인 버전").font(.caption).foregroundStyle(NovaStyle.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("설정")
        .novaScreen()
    }
}
