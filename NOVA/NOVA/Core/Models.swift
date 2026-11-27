import Foundation

// Models intentionally use stable string IDs for simple local persistence.
enum AIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case openai, anthropic, gemini
    var id: String { rawValue }
    var title: String {
        switch self { case .openai: return "GPT"; case .anthropic: return "Claude"; case .gemini: return "Gemini" }
    }
    var symbol: String {
        switch self { case .openai: return "sparkles.rectangle.stack"; case .anthropic: return "asterisk"; case .gemini: return "diamond.inset.filled" }
    }
    var tagline: String {
        switch self { case .openai: return "아이디어와 코딩"; case .anthropic: return "분석과 글쓰기"; case .gemini: return "다양한 관점의 탐색" }
    }
}

struct ChatTurn: Identifiable, Codable, Sendable {
    var id = UUID()
    var role: String
    var text: String
    var createdAt = Date()
    var attachmentNote: String? = nil
}

struct ChatRoom: Identifiable, Codable {
    var id = UUID()
    var provider: AIProvider
    var title: String = "새로운 대화"
    var turns: [ChatTurn] = []
    var updatedAt = Date()
}

struct Agent: Identifiable, Codable {
    var id = UUID()
    var name: String
    var provider: AIProvider
    var instruction: String
    var icon: String = "brain.head.profile"
}

struct AgentTeam: Identifiable, Codable {
    var id = UUID()
    var name: String
    var goal: String
    var agents: [Agent]
}

struct CompareAnswer: Identifiable, Codable {
    var id: String { provider.rawValue }
    var provider: AIProvider
    var text: String
    var error: String? = nil
}

struct Comparison: Identifiable, Codable {
    var id = UUID()
    var question: String
    var answers: [CompareAnswer]
    var synthesis: String? = nil
    var createdAt = Date()
}

struct AgentResult: Identifiable, Codable, Sendable {
    var id = UUID()
    var name: String
    var provider: AIProvider
    var output: String
}

struct WorkflowTrace: Identifiable, Codable, Sendable {
    var id = UUID()
    var stage: String
    var model: String
    var seconds: Double
    var output: String
    var demo: Bool
}

struct WorkflowRecord: Identifiable, Codable {
    var id = UUID()
    var title: String
    var goal: String
    var results: [AgentResult]
    var summary: String
    var demo: Bool
    var createdAt = Date()
    // Optional additions preserve decoding of NOVA 1.0/2.0 saved JSON.
    var trace: [WorkflowTrace]? = nil
    var review: String? = nil
    var fallbackUsed: Bool? = nil
    var revision: String? = nil // Optional: backward-compatible v5 quality iteration.
}

struct DebateRecord: Identifiable, Codable {
    var id = UUID()
    var topic: String
    var first: AIProvider
    var second: AIProvider
    var openingA: String
    var openingB: String
    var rebuttalA: String
    var rebuttalB: String
    var conclusion: String
    var createdAt = Date()
}

// NOVA 4.0 - Blind Arena models. Optional storage for migration from NOVA 1-3.
enum ArenaVote: String, Codable, CaseIterable, Sendable {
    case left, right, tie
}

struct ArenaAnswer: Codable, Sendable {
    let provider: AIProvider
    let text: String
    let error: String?
    var succeeded: Bool { error == nil && !text.isEmpty }
}

struct ArenaMatch: Identifiable, Codable, Sendable {
    var id = UUID()
    let prompt: String
    let left: ArenaAnswer
    let right: ArenaAnswer
    var vote: ArenaVote? = nil
    let demo: Bool
    var createdAt = Date()
    var isPlayable: Bool { left.succeeded && right.succeeded }
}

struct ArenaScore: Identifiable {
    let provider: AIProvider
    let wins: Int
    let appearances: Int
    var id: String { provider.rawValue }
    var percentage: Int { appearances == 0 ? 0 : Int(Double(wins) / Double(appearances) * 100.0) }
}

enum ArenaStats {
    static func scores(matches: [ArenaMatch], includeDemo: Bool) -> [ArenaScore] {
        let votes = matches.filter { $0.vote != nil && $0.isPlayable && (includeDemo || !$0.demo) }
        return AIProvider.allCases.map { p in
            let games = votes.filter { $0.left.provider == p || $0.right.provider == p }
            let wins = games.filter { m in
                (m.vote == .left && m.left.provider == p) || (m.vote == .right && m.right.provider == p)
            }.count
            return ArenaScore(provider: p, wins: wins, appearances: games.count)
        }
    }
}

struct PersistedData: Codable {
    var rooms: [ChatRoom] = []
    var teams: [AgentTeam] = AgentTeam.templates
    var comparisons: [Comparison] = []
    var workflows: [WorkflowRecord] = []
    var debates: [DebateRecord] = []
    var completedMissions: Int = 0
    var arenaMatches: [ArenaMatch]? = nil // Optional: old saved files decode safely.
    var documentInsights: [DocumentInsight]? = nil // NOVA 7: optional for v1-v6 compatibility.
    var workbenchReports: [WorkbenchReport]? = nil // NOVA 8: optional for v1-v7 compatibility.
}

extension AgentTeam {
    static let templates: [AgentTeam] = [
        .init(name: "앱 개발 드림팀", goal: "아이디어에서 검토까지", agents: [
            .init(name: "기획자", provider: .openai, instruction: "문제를 정의하고 실현 가능한 요구사항과 작업 계획을 구체적으로 작성해줘.", icon: "list.bullet.clipboard"),
            .init(name: "디자이너", provider: .anthropic, instruction: "사용자 여정, UX 구조, 접근성, 화면 흐름을 구체적으로 설계해줘.", icon: "paintbrush.pointed"),
            .init(name: "개발자", provider: .gemini, instruction: "구현 가능한 기술 아키텍처, API 구조, 데이터 모델과 단계별 개발 방법을 제안해줘.", icon: "chevron.left.forwardslash.chevron.right"),
            .init(name: "검토자", provider: .openai, instruction: "앞선 결과의 기술적 오류, 빠진 사항, 개인정보 위험과 검증 방법을 찾아줘.", icon: "checkmark.shield")
        ]),
        .init(name: "콘텐츠 연구소", goal: "조사하고 창작하고 검증하기", agents: [
            .init(name: "리서처", provider: .gemini, instruction: "주제의 핵심 사실과 확인할 사항을 조사 계획 형식으로 정리해줘. 실제 웹 검색을 수행하지 않는 한 확인했다고 표현하지 마.", icon: "magnifyingglass"),
            .init(name: "스토리텔러", provider: .anthropic, instruction: "창의적인 콘셉트, 메시지와 콘텐츠 초안을 구성해줘.", icon: "pencil.and.outline"),
            .init(name: "에디터", provider: .openai, instruction: "결과물의 논리와 표현을 검토하고 최종 개선안을 작성해줘.", icon: "text.badge.checkmark")
        ])
    ]
}
