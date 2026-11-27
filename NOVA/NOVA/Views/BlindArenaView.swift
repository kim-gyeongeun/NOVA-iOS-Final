import SwiftUI

/// The order is randomized per run. Provider identities only show after the user votes.
struct BlindArenaView: View {
    @EnvironmentObject private var store: NovaStore
    @AppStorage("demoMode") private var demoMode = true
    @State private var prompt = "내가 매일 겪는 불편함을 해결할 독창적이고 실현 가능한 앱 아이디어를 하나 제안해 줘."
    @State private var first: AIProvider = .openai
    @State private var second: AIProvider = .anthropic
    @State private var busy = false
    @State private var match: ArenaMatch?
    @State private var runTask: Task<Void, Never>?
    private let samples = [
        "복잡한 정보를 10분 안에 이해하는 새로운 방법을 제안해 줘.",
        "SwiftUI 앱의 사용성을 높이는 구체적 개선안 5개를 알려줘.",
        "대학생의 실제 불편함을 해결하는 AI 서비스 아이디어를 기획해 줘."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    SectionCaption(title: "블라인드 평가", subtitle: "모델 이름을 가리고 답변만 보고 평가하세요")
                    Spacer()
                    Text(demoMode ? "DEMO" : "LIVE")
                        .font(.caption2.bold())
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(demoMode ? Color.orange.opacity(0.16) : Color.green.opacity(0.16), in: Capsule())
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("질문을 입력하세요").font(.headline)
                        HangulTextInput("두 AI에게 보낼 질문", text: $prompt)
                            .frame(height: 106).disabled(busy)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(samples.indices, id: \.self) { index in
                                    Button("예시 \(index + 1)") { prompt = samples[index] }
                                        .buttonStyle(.bordered).disabled(busy)
                                }
                            }
                        }
                        Picker("AI 1", selection: $first) {
                            ForEach(AIProvider.allCases) { p in Text(p.title).tag(p) }
                        }.disabled(busy)
                        Picker("AI 2", selection: $second) {
                            ForEach(AIProvider.allCases) { p in Text(p.title).tag(p) }
                        }.disabled(busy)
                        Text("실행할 때 A/B 위치가 무작위로 결정됩니다. 모델명은 투표한 후 공개됩니다.")
                            .font(.caption).foregroundStyle(NovaStyle.muted)
                    }
                }
                if first == second { ErrorBanner(text: "서로 다른 두 모델을 골라 주세요.") }
                if !busy {
                    PrimaryAction("블라인드 대결 시작", icon: "eye.slash.fill") { start() }
                        .disabled(first == second || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 9) {
                            ProgressView().tint(NovaStyle.cyan)
                            Text("두 AI에 동시에 질문하고 있어요…").font(.subheadline)
                            Text("실제 API 연결 시 최대 2회의 모델 요청이 발생합니다.")
                                .font(.caption).foregroundStyle(NovaStyle.muted)
                            Button("실행 중단", role: .destructive) { runTask?.cancel(); busy = false }
                        }
                    }
                }
                if let match {
                    if match.demo { ErrorBanner(text: "데모 답변입니다. 실제 모델의 성능 비교 결과가 아닙니다.") }
                    arenaAnswer(title: "ANSWER A", answer: match.left, revealed: match.vote != nil)
                    arenaAnswer(title: "ANSWER B", answer: match.right, revealed: match.vote != nil)
                    if !match.isPlayable {
                        ErrorBanner(text: "하나 이상의 모델 호출이 실패했습니다. 이번 결과는 투표에 저장되지 않습니다. 서버 설정을 확인하고 다시 실행하세요.")
                    } else if match.vote == nil {
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("어떤 답변이 더 유용했나요?").font(.headline)
                                Text("모델은 투표 후 공개됩니다. 동일한 기준으로 판단해 보세요.")
                                    .font(.caption).foregroundStyle(NovaStyle.muted)
                                HStack {
                                    voteButton("A 선택", vote: .left)
                                    voteButton("B 선택", vote: .right)
                                    voteButton("무승부", vote: .tie)
                                }
                            }
                        }
                    } else {
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("MODEL REVEAL", systemImage: "eye.fill")
                                    .font(.headline).foregroundStyle(NovaStyle.cyan)
                                Text("A = \(match.left.provider.title)  ·  B = \(match.right.provider.title)")
                                    .font(.subheadline.bold())
                                Text("선택 결과: \(voteLabel(match))").font(.subheadline)
                                Text("아래 승률은 이 기기에서 직접 평가한 기록만 반영합니다. 객관적 AI 성능 지표가 아닙니다.")
                                    .font(.caption).foregroundStyle(NovaStyle.muted)
                            }
                        }
                    }
                }
                scorecard
                NavigationLink(destination: ArenaHistoryView()) {
                    Label("블라인드 아레나 전체 기록 보기", systemImage: "clock.arrow.circlepath")
                }.buttonStyle(.bordered)
                Text("AI 답변의 정확성은 별도 검증이 필요합니다. 블라인드란 모델명만 숨긴다는 뜻이며 문체로 추측할 수는 있습니다.")
                    .font(.caption2).foregroundStyle(NovaStyle.muted)
            }.padding(18)
        }.navigationTitle("블라인드 평가").novaScreen()
        .onDisappear { runTask?.cancel() }
    }

    @ViewBuilder private func arenaAnswer(title: String, answer: ArenaAnswer, revealed: Bool) -> some View {
        if let error = answer.error {
            ErrorBanner(text: "\(title) 요청 오류: \(error)")
        } else {
            ReadOnlyReport(title: revealed ? "\(title) · \(answer.provider.title)" : title, text: answer.text)
        }
    }

    private func voteButton(_ text: String, vote: ArenaVote) -> some View {
        Button(text) { castVote(vote) }
            .font(.caption.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(NovaStyle.purple.opacity(0.25), in: RoundedRectangle(cornerRadius: 11))
            .buttonStyle(.plain)
    }

    private var scorecard: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("모델별 투표 결과").font(.headline)
                    Spacer()
                    Text(demoMode ? "데모·실제 기록" : "실제 기록")
                        .font(.caption2).foregroundStyle(NovaStyle.muted)
                }
                ForEach(ArenaStats.scores(matches: store.data.arenaMatches ?? [], includeDemo: demoMode)) { score in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(score.provider.title).font(.subheadline.bold())
                            Spacer()
                            Text("\(score.wins)승 / \(score.appearances)회 · \(score.percentage)%")
                                .font(.caption).foregroundStyle(NovaStyle.muted)
                        }
                        ProgressView(value: Double(score.percentage), total: 100)
                            .tint(NovaStyle.cyan)
                    }
                }
            }
        }
    }

    private func start() {
        guard first != second, !busy else { return }
        let taskPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !taskPrompt.isEmpty else { return }
        match = nil; busy = true
        let p1 = first, p2 = second
        runTask = Task { @MainActor in
            let result = await ArenaEngine().play(prompt: taskPrompt, providerA: p1, providerB: p2)
            if !Task.isCancelled { match = result }
            busy = false; runTask = nil
        }
    }

    private func castVote(_ vote: ArenaVote) {
        guard var chosen = match, chosen.vote == nil, chosen.isPlayable else { return }
        chosen.vote = vote
        match = chosen
        store.saveArenaMatch(chosen)
    }

    private func voteLabel(_ item: ArenaMatch) -> String {
        switch item.vote {
        case .left: return "A (\(item.left.provider.title))"
        case .right: return "B (\(item.right.provider.title))"
        case .tie: return "무승부"
        case nil: return "미투표"
        }
    }
}

struct ArenaHistoryView: View {
    @EnvironmentObject private var store: NovaStore
    @State private var showDeleteConfirmation = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(title: "평가 기록", subtitle: "내가 선택한 답변과 모델별 결과")
                if (store.data.arenaMatches ?? []).isEmpty {
                    GlassPanel { Text("아직 투표 기록이 없습니다.").foregroundStyle(NovaStyle.muted) }
                }
                ForEach(store.data.arenaMatches ?? []) { item in
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Text(item.demo ? "DEMO" : "LIVE").font(.caption2.bold())
                                    .foregroundStyle(item.demo ? .orange : NovaStyle.cyan)
                                Spacer()
                                Text(item.createdAt, style: .date).font(.caption2).foregroundStyle(NovaStyle.muted)
                            }
                            Text(item.prompt).font(.subheadline.bold()).lineLimit(3)
                            Text("A · \(item.left.provider.title) / B · \(item.right.provider.title)")
                                .font(.caption).foregroundStyle(NovaStyle.muted)
                            Text("내 선택: \(item.vote == .left ? item.left.provider.title : item.vote == .right ? item.right.provider.title : "무승부")")
                                .font(.caption).foregroundStyle(NovaStyle.cyan)
                            DisclosureGroup("답변 다시 보기") {
                                Text("A · \(item.left.provider.title)\n\(item.left.text)")
                                Divider()
                                Text("B · \(item.right.provider.title)\n\(item.right.text)")
                            }.font(.caption).textSelection(.enabled)
                        }
                    }
                }
                if !(store.data.arenaMatches ?? []).isEmpty {
                    Button("아레나 기록 모두 삭제", role: .destructive) { showDeleteConfirmation = true }
                        .buttonStyle(.bordered)
                }
            }.padding(18)
        }.navigationTitle("평가 기록").novaScreen()
        .confirmationDialog("아레나 기록을 모두 삭제할까요?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("모두 삭제", role: .destructive) { store.clearArenaMatches() }
            Button("취소", role: .cancel) { }
        }
    }
}
