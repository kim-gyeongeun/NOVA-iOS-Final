import Foundation

/// Utilities shared by the editor, runner and export screens. No network calls.
enum TeamStudioRules {
    static let maximumAgents = 5

    static func validate(name: String, agents: [Agent]) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "팀 이름을 입력하세요." }
        if agents.isEmpty { return "에이전트를 한 명 이상 추가하세요." }
        if agents.count > maximumAgents { return "에이전트는 최대 5명까지 가능합니다." }
        if agents.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return "모든 에이전트의 역할과 지시문을 입력하세요."
        }
        return nil
    }

    static func duplicated(_ team: AgentTeam) -> AgentTeam {
        AgentTeam(name: "\(team.name) 복사본", goal: team.goal,
                  agents: team.agents.map { agent in
                      Agent(name: agent.name, provider: agent.provider,
                            instruction: agent.instruction, icon: agent.icon)
                  })
    }
}

enum MissionBlueprint: String, CaseIterable, Identifiable {
    case general = "자유 협업"
    case product = "서비스 기획"
    case decision = "의사결정 검토"
    case study = "학습 프로젝트"
    case presentation = "발표 준비"

    var id: String { rawValue }
    var criteria: String {
        switch self {
        case .general: return "요청의 핵심을 모두 다루고 불확실한 내용은 별도로 표시"
        case .product: return "사용자 문제, 핵심 기능, MVP 범위, 기술 위험, 검증 방법 포함"
        case .decision: return "대안 2개 이상 비교, 판단 기준과 반론, 추가 확인 사항 포함"
        case .study: return "핵심 개념, 학습 순서, 연습 문제, 자기 점검 방법 포함"
        case .presentation: return "발표 흐름, 슬라이드 개요, 시연 계획, 예상 질문 포함"
        }
    }
    var format: String {
        switch self {
        case .general: return "핵심 요약 → 단계별 실행안 → 검증 필요 사항"
        case .product: return "문제 정의 → 핵심 사용자 → 기능 명세 → 화면 구조 → MVP 로드맵"
        case .decision: return "선택지 표 → 장단점 → 조건부 추천 → 검증할 가정"
        case .study: return "학습 목표 → 설명 → 예시 → 퀴즈 → 정답 및 해설"
        case .presentation: return "발표 제목 → 슬라이드별 요점 → 시연 → 질문 대비"
        }
    }
}

enum WorkflowExporter {
    static func markdown(_ record: WorkflowRecord) -> String {
        var sections = [
            "# NOVA Mission Report — \(record.title)",
            "", "- 목표: \(record.goal)",
            "- 실행 방식: \(record.demo ? "DEMO (예시 응답)" : "LIVE API")",
            "- 생성 시각: \(ISO8601DateFormatter().string(from: record.createdAt))",
            "", "## 최종 보고서", record.summary
        ]
        if let review = record.review, !review.isEmpty {
            sections += ["", "## QA 검토", review]
        }
        if let revision = record.revision, !revision.isEmpty {
            sections += ["", "## 개선 초안", revision]
        }
        if let trace = record.trace, !trace.isEmpty {
            sections += ["", "## 작업 단계별 기록"]
            for event in trace {
                sections += ["", "### \(event.stage) — \(event.model)", event.output]
            }
        }
        sections += ["", "---", "AI 산출물은 실제 사실 검증이나 실행 테스트를 대체하지 않습니다."]
        return sections.joined(separator: "\n")
    }
}
