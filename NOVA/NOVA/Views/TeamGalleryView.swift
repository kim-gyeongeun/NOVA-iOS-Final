import SwiftUI

// Installable presets: each preset uses the same real WorkflowEngine as hand-built teams.
private struct TeamPack: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let objective: String
    let agents: [Agent]
    var team: AgentTeam { .init(name: title, goal: objective, agents: agents) }
}

private enum TeamPacks {
    static let available: [TeamPack] = [
        .init(id: "startup", title: "스타트업 런치팀", subtitle: "문제 발견 → 검증 → 사업 계획", symbol: "paperplane.fill", objective: "실제 고객의 문제를 검증하고 실행 가능한 초기 제품과 수익 모델을 설계하기", agents: [
            .init(name: "문제 탐색가", provider: .gemini, instruction: "목표 고객과 핵심 불편함, 검증이 필요한 가정을 정의하세요."),
            .init(name: "제품 전략가", provider: .openai, instruction: "핵심 가치 제안, MVP 기능, 단계별 구현 범위를 작성하세요."),
            .init(name: "비즈니스 분석가", provider: .anthropic, instruction: "비용, 수익 가능성, 주요 리스크와 대체재를 비판적으로 검토하세요."),
            .init(name: "피치 코치", provider: .openai, instruction: "발표용 핵심 메시지와 검증 계획을 간결하게 정리하세요.")
        ]),
        .init(id: "bug", title: "버그 헌터즈", subtitle: "원인 추론 → 수정 설계 → 재검증", symbol: "ladybug.fill", objective: "SwiftUI 또는 다른 소프트웨어 오류를 체계적으로 분석하고 재현·수정·검증 계획 만들기", agents: [
            .init(name: "트리아지", provider: .openai, instruction: "증상, 재현 단계, 입력 조건, 로그에서 확인할 내용을 구조화하세요."),
            .init(name: "루트 코즈", provider: .anthropic, instruction: "가능성 높은 원인과 낮은 원인을 구분하고 반례를 제시하세요."),
            .init(name: "패치 개발자", provider: .openai, instruction: "수정 코드 또는 의사코드와 변경 이유를 제안하세요. 실행했다고 주장하지 마세요."),
            .init(name: "QA", provider: .gemini, instruction: "회귀 테스트, 경계 조건, 수동 검증 체크리스트를 제안하세요.")
        ]),
        .init(id: "study", title: "시험 대비 학습팀", subtitle: "핵심 정리 → 문제 생성 → 오답 분석", symbol: "graduationcap.fill", objective: "학습 자료와 사용자가 설명한 실력을 바탕으로 이해도 중심의 학습 계획 만들기", agents: [
            .init(name: "개념 튜터", provider: .openai, instruction: "핵심 개념을 초보자도 이해할 수 있는 예시로 설명하세요."),
            .init(name: "문제 출제자", provider: .gemini, instruction: "핵심 개념을 확인할 연습 문제와 정답 근거를 작성하세요."),
            .init(name: "오답 코치", provider: .anthropic, instruction: "헷갈리기 쉬운 선택지, 오개념과 복습 순서를 제안하세요.")
        ]),
        .init(id: "product", title: "UX 프로덕트 랩", subtitle: "사용자 여정 → UI → 접근성 리뷰", symbol: "square.on.circle.fill", objective: "사용자가 실제로 겪는 문제에서 출발해 기능·흐름·접근성을 함께 갖춘 iOS 앱 설계하기", agents: [
            .init(name: "UX 리서처", provider: .anthropic, instruction: "페르소나와 사용 시나리오를 제안하되 실제 조사와 가정을 구분하세요."),
            .init(name: "인터랙션 디자이너", provider: .gemini, instruction: "핵심 화면, 빈 상태, 오류 상태, 상호작용 흐름을 설계하세요."),
            .init(name: "iOS 엔지니어", provider: .openai, instruction: "SwiftUI 구성 요소, 데이터 모델, 구현 단계를 제안하세요."),
            .init(name: "접근성 리뷰어", provider: .anthropic, instruction: "VoiceOver, Dynamic Type, 색 대비, 사용성 문제를 검토하세요.")
        ]),
        .init(id: "content", title: "크리에이터 스튜디오", subtitle: "콘셉트 → 스토리 → 편집", symbol: "theatermasks.fill", objective: "차별화된 콘텐츠 콘셉트부터 제작 계획과 최종 대본까지 완성하기", agents: [
            .init(name: "콘셉트 디렉터", provider: .gemini, instruction: "익숙한 클리셰를 피해 여러 차별화 콘셉트를 제안하세요."),
            .init(name: "스토리 작가", provider: .anthropic, instruction: "등장인물·감정선·전개 구조를 일관성 있게 작성하세요."),
            .init(name: "에디터", provider: .openai, instruction: "논리적 연결, 몰입도, 톤, 제작 난이도를 점검하세요.")
        ]),
        .init(id: "decision", title: "의사결정 위원회", subtitle: "찬성 · 반대 · 리스크 · 결론", symbol: "scale.3d", objective: "두 가지 이상 선택지의 장단점과 불확실성을 검토하고 판단 기준을 제안하기", agents: [
            .init(name: "찬성 분석가", provider: .openai, instruction: "선택의 기회와 효용을 근거·가정과 함께 제시하세요."),
            .init(name: "반대 분석가", provider: .anthropic, instruction: "선택의 비용, 실패 가능성, 놓친 반례를 검토하세요."),
            .init(name: "대안 탐색가", provider: .gemini, instruction: "이분법을 넘어 절충안과 새로운 선택지를 제안하세요."),
            .init(name: "의장", provider: .openai, instruction: "검증되지 않은 정보와 판단 기준을 구분하고 결론을 조건부로 정리하세요.")
        ])
    ]
}

struct TeamGalleryView: View {
    @EnvironmentObject private var store: NovaStore
    @State private var chosen: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                SectionCaption(title: "팀 템플릿", subtitle: "역할이 미리 구성된 팀에서 시작하세요")
                GlassPanel {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("ONE-TAP AGENT TEAMS", systemImage: "person.3.fill").font(.caption.weight(.bold)).foregroundStyle(NovaStyle.cyan)
                        Text("전문가 팀 6개").font(.title2.weight(.bold))
                        Text("각 팀의 역할과 모델은 자유롭게 수정할 수 있는 출발점이에요. 실제 웹 검색·코드 실행처럼 연결되지 않은 도구를 수행했다고 주장하지 않도록 설계했어요.")
                            .font(.caption).foregroundStyle(NovaStyle.muted)
                    }
                }
                ForEach(TeamPacks.available) { pack in
                    let installed = store.data.teams.contains { $0.name == pack.title }
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack(spacing: 13) {
                                Image(systemName: pack.symbol).font(.title2).foregroundStyle(NovaStyle.cyan)
                                    .frame(width: 48, height: 48).background(NovaStyle.purple.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pack.title).font(.headline)
                                    Text(pack.subtitle).font(.caption).foregroundStyle(NovaStyle.muted)
                                }
                                Spacer()
                                Text("에이전트 \(pack.agents.count)명").font(.system(size: 10, weight: .bold)).foregroundStyle(NovaStyle.cyan)
                            }
                            Text(pack.objective).font(.caption).foregroundStyle(NovaStyle.muted)
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(pack.agents) { agent in
                                    HStack(spacing: 8) {
                                        Image(systemName: agent.provider.symbol).foregroundStyle(NovaStyle.cyan)
                                        Text(agent.name).font(.caption)
                                        Spacer()
                                        Text(agent.provider.title).font(.caption2).foregroundStyle(NovaStyle.muted)
                                    }
                                }
                            }
                            Button {
                                store.addTeam(pack.team)
                                chosen = "\(pack.title) 팀을 추가했어요. '팀 스튜디오'에서 바로 실행할 수 있어요."
                            } label: {
                                Label(installed ? "같은 템플릿으로 새 팀 추가" : "내 팀에 추가", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity).padding(12)
                                    .background(NovaStyle.purple.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }.padding(18)
        }
        .navigationTitle("팀 템플릿")
        .novaScreen()
        .alert("팀 추가 완료", isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } })) {
            Button("확인", role: .cancel) { chosen = nil }
        } message: { Text(chosen ?? "") }
    }
}
