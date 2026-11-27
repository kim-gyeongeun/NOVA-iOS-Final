import SwiftUI

struct SmartRouterView: View {
    @EnvironmentObject private var store: NovaStore
    @AppStorage("demoMode") private var demoMode = true
    @State private var question = "SwiftUI 앱에서 이미지가 표시되지 않는 오류를 해결하고 싶어. 원인과 수정 코드를 설명해줘."
    @State private var automatic = true
    @State private var manualProvider: AIProvider = .openai
    @State private var busy = false
    @State private var result: String?
    @State private var errorText: String?
    @State private var selectedProvider: AIProvider?
    @State private var routeNote: String?
    @State private var savedRoom: UUID?

    private var decision: SmartRoutingDecision { SmartRouter.recommend(question) }
    private var currentProvider: AIProvider { automatic ? decision.preferred : manualProvider }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                SectionCaption(title: "AI 모델 추천", subtitle: "질문 유형에 맞는 모델을 추천해 드려요")
                VStack(alignment: .leading, spacing: 9) {
                    Text("빠르게 체험하기").font(.caption.weight(.semibold)).foregroundStyle(NovaStyle.muted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            sampleButton("SwiftUI 오류", prompt: "SwiftUI 코드에서 컴파일 오류가 발생했어. 원인과 수정 방법을 알려줘.", icon: "curlybraces")
                            sampleButton("기획 아이디어", prompt: "AI 앱 창업 아이디어를 독창적으로 기획해줘.", icon: "lightbulb")
                            sampleButton("문장 다듬기", prompt: "교수님께 보낼 이메일 문장을 자연스럽게 편집해줘.", icon: "pencil")
                            sampleButton("시험 공부", prompt: "토익 초보가 이해하도록 품사 개념을 쉽게 설명해줘.", icon: "graduationcap")
                        }
                    }
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 11) {
                        Label("MISSION INPUT", systemImage: "text.bubble.fill")
                            .font(.caption.weight(.bold)).foregroundStyle(NovaStyle.cyan)
                        HangulTextInput("AI에게 질문해 보세요", text: $question)
                            .frame(height: 122)
                        Text("질문을 기기에서 먼저 분류합니다. 추천은 간단한 규칙 기반이며 실제 모델 성능 순위가 아니에요.")
                            .font(.caption2).foregroundStyle(NovaStyle.muted)
                    }
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $automatic) {
                            Label("AI 자동 추천", systemImage: "point.3.connected.trianglepath.dotted")
                                .font(.headline)
                        }.tint(NovaStyle.cyan)
                        HStack(spacing: 12) {
                            Image(systemName: decision.task.symbol).font(.title2).foregroundStyle(NovaStyle.cyan)
                                .frame(width: 47, height: 47).background(NovaStyle.purple.opacity(0.22), in: RoundedRectangle(cornerRadius: 13))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("인식한 작업: \(decision.task.title)").font(.subheadline.weight(.bold))
                                Text(decision.reasoning).font(.caption).foregroundStyle(NovaStyle.muted)
                            }
                        }
                        if automatic {
                            HStack {
                                Text("추천 모델").font(.caption).foregroundStyle(NovaStyle.muted)
                                Spacer()
                                ProviderPill(provider: decision.preferred)
                            }
                        } else {
                            Picker("직접 선택", selection: $manualProvider) {
                                ForEach(AIProvider.allCases) { provider in
                                    Text(provider.title).tag(provider)
                                }
                            }.pickerStyle(.segmented)
                        }
                        Text("선호 모델을 직접 사용하려면 자동 추천을 끄세요. API가 설정되지 않은 모델은 실사용할 수 없습니다.")
                            .font(.caption2).foregroundStyle(NovaStyle.muted)
                    }
                }
                PrimaryAction("스마트 질문 실행", icon: "bolt.fill", busy: busy) {
                    Task { await execute() }
                }.disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let routeNote { Label(routeNote, systemImage: "point.topleft.down.to.point.bottomright.curvepath").font(.caption).foregroundStyle(NovaStyle.cyan) }
                if let errorText { ErrorBanner(text: errorText) }
                if let result {
                    if demoMode { Label("DEMO: 아래는 AI가 생성한 답변이 아닌 예시입니다.", systemImage: "info.circle").font(.caption).foregroundStyle(.orange) }
                    ReadOnlyReport(title: "\(selectedProvider?.title ?? "AI") · 결과", text: result)
                    if savedRoom != nil {
                        Button {
                            // Reopen the exact persisted conversation so the response can be continued.
                            if let id = savedRoom { openedRoom = id }
                        } label: {
                            Label("이 답변에서 대화 이어가기", systemImage: "bubble.left.and.text.bubble.right")
                                .font(.headline).frame(maxWidth: .infinity).padding(15)
                                .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }.padding(18)
        }
        .navigationTitle("모델 추천")
        .novaScreen()
        .navigationDestination(isPresented: Binding(
                get: { openedRoom != nil },
                set: { if !$0 { openedRoom = nil } }
            )) {
                if let id = openedRoom { ChatRoomView(roomID: id) }
            }
    }

    @State private var openedRoom: UUID?

    private func sampleButton(_ title: String, prompt: String, icon: String) -> some View {
        Button { question = prompt } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(NovaStyle.panel, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @MainActor private func execute() async {
        let prompt = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !busy else { return }
        busy = true; result = nil; errorText = nil; routeNote = nil; savedRoom = nil
        defer { busy = false }
        var provider = currentProvider
        let task = decision.task
        do {
            if !demoMode {
                let status = try await AIService().health()
                if status.providers[provider.rawValue] != true {
                    if automatic, let fallback = AIProvider.allCases.first(where: { status.providers[$0.rawValue] == true }) {
                        routeNote = "추천한 \(provider.title)의 API가 없어 \(fallback.title)로 대체했어요."
                        provider = fallback
                    } else {
                        throw NovaError.server("\(provider.title) API 키가 준비되지 않았어요. 설정에서 서버 연결과 API 키를 확인하세요.")
                    }
                }
            }
            selectedProvider = provider
            let answer = try await AIService().ask(provider, message: prompt, system: task.systemInstruction)
            let roomID = store.addRoom(provider)
            var room = store.data.rooms.first { $0.id == roomID }!
            room.title = "[Smart] " + String(prompt.prefix(29))
            room.turns = [ChatTurn(role: "user", text: prompt), ChatTurn(role: "assistant", text: answer)]
            room.updatedAt = Date()
            store.updateRoom(room)
            savedRoom = roomID
            result = answer
            if routeNote == nil { routeNote = "\(task.title) → \(provider.title) · 결과가 AI Hub에 저장됐어요." }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
