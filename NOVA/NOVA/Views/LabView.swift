import SwiftUI

struct LabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                SectionCaption(title: "모든 AI 도구", subtitle: "필요한 작업만 골라 시작하세요")
                    .padding(.bottom, 5)
                NavigationLink(destination: WorkbenchView()) { LabTile(icon: "square.and.pencil", title: "보고서 작업실", desc: "AI 기록을 결합하고 보고서를 편집·저장", tag: "작성") }.buttonStyle(.plain)
                NavigationLink(destination: DocumentStudioView()) { LabTile(icon: "doc.text.viewfinder", title: "문서 분석", desc: "사진과 PDF 인식, 요약 및 질문 생성", tag: "분석") }.buttonStyle(.plain)
                NavigationLink(destination: SmartRouterView()) { LabTile(icon: "arrow.triangle.branch", title: "AI 자동 추천", desc: "질문 유형에 맞는 AI 모델 안내", tag: "추천") }.buttonStyle(.plain)
                NavigationLink(destination: CompareView()) { LabTile(icon: "rectangle.split.3x1", title: "모델 비교", desc: "같은 질문을 세 AI에 보내 답변 비교", tag: "비교") }.buttonStyle(.plain)
                NavigationLink(destination: BlindArenaView()) { LabTile(icon: "eye.slash", title: "블라인드 아레나", desc: "모델 이름을 숨긴 채 답변 평가", tag: "실험") }.buttonStyle(.plain)
                NavigationLink(destination: DebateView()) { LabTile(icon: "bubble.left.and.bubble.right", title: "AI 토론", desc: "서로 다른 AI에게 찬반 논증 요청", tag: "토론") }.buttonStyle(.plain)
                NavigationLink(destination: PromptForgeView()) { LabTile(icon: "text.badge.plus", title: "프롬프트 편집", desc: "질문을 더 명확한 작업 지시문으로 개선", tag: "도구") }.buttonStyle(.plain)
                NavigationLink(destination: MissionView()) { LabTile(icon: "lightbulb", title: "랜덤 미션", desc: "짧은 창의력 문제와 AI 힌트", tag: "실험") }.buttonStyle(.plain)
            }.padding(18)
        }.navigationTitle("AI 도구").novaScreen()
    }
}

struct LabTile: View {
    let icon: String; let title: String; let desc: String; let tag: String
    var body: some View {
        HStack(spacing: 14) {
            NovaFeatureIcon(symbol: icon, size: 46)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NovaStyle.ink)
                Text(desc)
                    .font(.footnote)
                    .foregroundStyle(NovaStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NovaStyle.muted)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(NovaStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct CompareView: View {
    @EnvironmentObject private var store: NovaStore
    @State private var prompt = "AI로 개발한 아이폰 앱을 실용적으로 차별화하려면 어떻게 해야 할까?"
    @State private var busy = false
    @State private var comparison: Comparison?
    @State private var merging = false
    @State private var errorText: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionCaption(title: "AI 답변 비교", subtitle: "같은 질문에 대한 다양한 모델의 답변")
                HangulTextInput("비교할 질문", text: $prompt)
                    .frame(height: 106).padding().background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                PrimaryAction("3개 AI에 동시 질문", icon: "arrow.triangle.branch", busy: busy) {
                    busy = true
                    Task {
                        let result = await WorkflowEngine().compare(question: prompt)
                        comparison = result; store.saveComparison(result); busy = false
                    }
                }
                if let result = comparison {
                    ForEach(result.answers) { answer in
                        if let error = answer.error { ErrorBanner(text: "\(answer.provider.title): \(error)") }
                        else { ReadOnlyReport(title: answer.provider.title, text: answer.text) }
                    }
                    if let synthesis = result.synthesis { ReadOnlyReport(title: "NOVA FUSION · 비교 분석", text: synthesis) }
                    else {
                        PrimaryAction("3개 답변 융합·차이점 찾기", icon: "point.3.connected.trianglepath.dotted", busy: merging) {
                            merging = true; errorText = nil
                            Task {
                                do {
                                    let context = result.answers.map { "[\($0.provider.title)]\n\($0.error ?? $0.text)" }.joined(separator: "\n\n")
                                    let fused = try await AIService().ask(.openai, message: "질문: \(result.question)\n\nAI 답변들:\n\(context)\n\n공통 주장, 뚜렷하게 다른 주장, 검증되지 않은 내용, 종합 권장안을 각각 분리해 설명해줘. 모델 합의만으로 사실을 단정하지 마.")
                                    var copy = result; copy.synthesis = fused; comparison = copy; store.saveComparison(copy)
                                } catch { errorText = error.localizedDescription }
                                merging = false
                            }
                        }
                    }
                    if let errorText { ErrorBanner(text: errorText) }
                    Text("참고: AI들이 동의하더라도 답변의 사실성이 보장되지는 않습니다.").font(.caption).foregroundStyle(NovaStyle.muted)
                }
            }.padding(18)
        }.navigationTitle("답변 비교").novaScreen()
    }
}

struct DebateView: View {
    @EnvironmentObject private var store: NovaStore
    @State private var topic = "AI가 만든 콘텐츠에도 인간과 같은 창작자 권리를 부여해야 할까?"
    @State private var first: AIProvider = .openai
    @State private var second: AIProvider = .anthropic
    @State private var busy = false
    @State private var status = ""
    @State private var result: DebateRecord?
    @State private var errorText: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                SectionCaption(title: "AI 토론", subtitle: "서로 다른 모델에 찬반 역할을 맡겨보세요")
                HangulTextInput("토론 주제", text: $topic).frame(height: 86)
                    .padding().background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("찬성 AI", selection: $first) { ForEach(AIProvider.allCases) { p in Text(p.title).tag(p) } }
                        Picker("반대 AI", selection: $second) { ForEach(AIProvider.allCases) { p in Text(p.title).tag(p) } }
                    }
                }
                if first == second { ErrorBanner(text: "서로 다른 AI 두 개를 선택해 주세요.") }
                if busy { Label(status, systemImage: "arrow.triangle.2.circlepath").foregroundStyle(NovaStyle.cyan) }
                PrimaryAction("토론 시작 · 2라운드", icon: "bubble.left.and.bubble.right", busy: busy) {
                    guard first != second, !topic.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    busy = true; errorText = nil; result = nil
                    Task {
                        do {
                            let record = try await WorkflowEngine().debate(topic: topic, first: first, second: second) { status = $0 }
                            result = record; store.saveDebate(record)
                        } catch { errorText = error.localizedDescription }
                        busy = false
                    }
                }
                .disabled(first == second || topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let errorText { ErrorBanner(text: errorText) }
                if let result {
                    ReadOnlyReport(title: "1라운드 · \(result.first.title) 찬성", text: result.openingA)
                    ReadOnlyReport(title: "1라운드 · \(result.second.title) 반대", text: result.openingB)
                    ReadOnlyReport(title: "2라운드 · 찬성 측 반박", text: result.rebuttalA)
                    ReadOnlyReport(title: "2라운드 · 반대 측 반박", text: result.rebuttalB)
                    ReadOnlyReport(title: "중립적 쟁점 정리", text: result.conclusion)
                }
            }.padding(18)
        }.navigationTitle("AI 토론").novaScreen()
    }
}

struct PromptForgeView: View {
    @State private var prompt = "좋은 앱 아이디어 추천해줘"
    @State private var purpose = "기술적으로 상세하게"
    @State private var provider: AIProvider = .openai
    @State private var result: String?
    @State private var busy = false
    @State private var errorText: String?
    private let purposes = ["기술적으로 상세하게", "기발하고 창의적으로", "초보자도 이해하기 쉽게", "회의용 문서로", "반대 의견까지 분석"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                SectionCaption(title: "질문 다듬기", subtitle: "AI가 이해하기 쉬운 요청으로 개선하세요")
                HangulTextInput("원본 프롬프트", text: $prompt).frame(height: 106)
                    .padding().background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                GlassPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("개선 방향", selection: $purpose) { ForEach(purposes, id: \.self) { Text($0) } }
                        Picker("사용 AI", selection: $provider) { ForEach(AIProvider.allCases) { p in Text(p.title).tag(p) } }
                    }
                }
                PrimaryAction("프롬프트 강화", icon: "wand.and.stars", busy: busy) {
                    busy = true; result = nil; errorText = nil
                    Task {
                        do {
                            result = try await AIService().ask(provider, message: "다음 프롬프트를 '\(purpose)' 방향으로 개선하되, 목적, 입력, 출력 형식, 제약, 검증 기준을 담은 사용 가능한 프롬프트 하나를 만들어 줘. 프롬프트만 출력해.\n원본: \(prompt)")
                        } catch { errorText = error.localizedDescription }
                        busy = false
                    }
                }
                if let errorText { ErrorBanner(text: errorText) }
                if let result { ReadOnlyReport(title: "개선된 프롬프트", text: result) }
            }.padding(18)
        }.navigationTitle("질문 다듬기").novaScreen()
    }
}

struct MissionView: View {
    @EnvironmentObject private var store: NovaStore
    @State private var current = 0
    @State private var showAnswer = false
    @State private var answer: String?
    @State private var busy = false
    private let missions = [
        "평소 불편한 행동 하나를 고르고, 앱 없이도 실험 가능한 해결법 3개를 만들어 봐.",
        "10분 안에 만들 수 있는 기발한 서비스의 핵심 화면을 기획해 봐.",
        "AI가 틀릴 수 있는 주장 3개를 만들고, 어떤 증거로 검증할지 생각해 봐.",
        "서로 다른 직업 세 가지의 고민을 하나의 서비스로 해결하는 아이디어를 만들어 봐.",
        "쓸모없어 보이는 생활용품을 완전히 다른 목적으로 활용할 방법을 제안해 봐.",
        "내가 매일 미루는 일 하나를 2분 안에 시작하게 만드는 인터페이스를 설계해 봐.",
        "동일한 문제에 대해 정반대 입장의 해결책을 각각 만들어 봐."
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                SectionCaption(title: "창의력 미션", subtitle: "짧은 미션으로 아이디어를 발굴해 보세요")
                GlassPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        Label("TODAY'S QUEST", systemImage: "dice.fill").font(.caption.weight(.bold)).foregroundStyle(NovaStyle.cyan)
                        Text(missions[current]).font(.title3.weight(.semibold)).lineSpacing(5)
                        Text("완료한 미션 \(store.data.completedMissions)개").font(.caption).foregroundStyle(NovaStyle.muted)
                    }.padding(5)
                }
                Button { current = (current + 1) % missions.count; answer = nil; showAnswer = false } label: {
                    Label("다른 미션 뽑기", systemImage: "shuffle").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
                PrimaryAction("AI 힌트 받기", icon: "lightbulb", busy: busy) {
                    busy = true
                    Task {
                        do { answer = try await AIService().ask(.openai, message: "이 창의력 미션을 위한 실용적인 아이디어 3개를 제안해 줘: \(missions[current])") }
                        catch { answer = error.localizedDescription }
                        busy = false
                    }
                }
                if let answer { ReadOnlyReport(title: "AI 힌트", text: answer) }
                Button {
                    store.missionCompleted(); showAnswer = true
                } label: { Label(showAnswer ? "미션 기록 완료!" : "미션 완료 기록", systemImage: "checkmark.seal.fill") }
                    .buttonStyle(.borderedProminent).disabled(showAnswer)
            }.padding(18)
        }.navigationTitle("창의력 미션").novaScreen()
    }
}
