import SwiftUI

/// Shows truthful connection status: configured != verified.
struct ConnectionCenterView: View {
    @AppStorage("demoMode") private var demoMode = true
    @AppStorage("serverURL") private var serverURL = "http://127.0.0.1:8765"
    @State private var providers: [ProviderConnection] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var results: [String: String] = [:]
    @State private var busy: Set<String> = []

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundStyle(NovaStyle.cyan)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI 연결 관리").font(.headline)
                        Text("API 키는 Mac 서버에만 저장됩니다.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                TextField("서버 주소", text: $serverURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.URL)
                Button {
                    Task { await refresh() }
                } label: {
                    HStack {
                        Label("연결 상태 새로고침", systemImage: "arrow.clockwise")
                        Spacer()
                        if loading { ProgressView() }
                    }
                }.disabled(loading)
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            } header: { Text("서버") } footer: {
                Text("시뮬레이터는 Mac에서 실행 중인 서버의 127.0.0.1:8765를 사용합니다. 실제 아이폰은 Mac과 같은 Wi-Fi에서 Mac의 IP 주소를 입력하세요. 로컬 서버를 인터넷에 공개하면 안 됩니다.")
            }

            Section("모델별 연결 상태") {
                if providers.isEmpty && !loading {
                    Text("상태를 불러오려면 위 버튼을 누르세요.")
                        .foregroundStyle(.secondary)
                }
                ForEach(providers) { entry in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(displayName(entry.id)).font(.headline)
                                Text(entry.model).font(.caption.monospaced()).foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            Label(entry.configured ? "키 설정됨" : "키 없음", systemImage: entry.configured ? "key.fill" : "key.slash")
                                .font(.caption)
                                .foregroundStyle(entry.configured ? .green : .orange)
                        }
                        if let result = results[entry.id] {
                            Text(result).font(.footnote).foregroundStyle(result.hasPrefix("성공") ? .green : .orange)
                                .textSelection(.enabled)
                        }
                        Button {
                            Task { await test(entry.id) }
                        } label: {
                            HStack {
                                Label("실제 API 응답 확인", systemImage: "checkmark.shield")
                                Spacer()
                                if busy.contains(entry.id) { ProgressView() }
                            }
                        }.disabled(!entry.configured || busy.contains(entry.id))
                    }.padding(.vertical, 4)
                }
            }
            Section("시작하기") {
                Label("Mac에서 Backend/configure_keys.command로 키를 설정하세요.", systemImage: "1.circle")
                Label("Backend/start_macos.command로 서버를 실행하세요.", systemImage: "2.circle")
                Label("실제 응답 테스트 성공 후 데모 모드를 끄세요.", systemImage: "3.circle")
                Toggle("데모 모드", isOn: $demoMode)
                Text("키가 설정됐다는 것은 연결 성공을 뜻하지 않습니다. 실제 응답 테스트를 통과해야 LIVE 연결을 확인할 수 있습니다. 테스트 호출에는 요금이 발생할 수 있습니다. 키는 절대 앱이나 채팅창에 입력하지 마세요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("AI 연결 센터")
        .scrollContentBackground(.hidden)
        .novaScreen()
        .task { await refresh() }
    }

    private func displayName(_ id: String) -> String {
        switch id {
        case "openai": return "OpenAI · GPT"
        case "anthropic": return "Anthropic · Claude"
        case "gemini": return "Google · Gemini"
        default: return id
        }
    }

    @MainActor private func refresh() async {
        loading = true
        defer { loading = false }
        do {
            providers = try await AIService().connections()
            errorMessage = nil
            results = [:]
        } catch {
            providers = []
            errorMessage = "서버 연결 실패: \(error.localizedDescription)"
        }
    }

    @MainActor private func test(_ id: String) async {
        guard let provider = AIProvider(rawValue: id) else { return }
        busy.insert(id)
        results[id] = "테스트 중..."
        defer { busy.remove(id) }
        do {
            let result = try await AIService().probe(provider)
            results[id] = "성공 · \(result.model) · \(result.elapsed_ms)ms\n응답: \(result.preview)"
        } catch {
            results[id] = "실패 · \(error.localizedDescription)"
        }
    }
}
