import Foundation

// A transparent, offline rule-based suggestion. This is NOT a measured benchmark
// of model performance; users can always override the selected provider.
enum SmartTask: String, CaseIterable {
    case coding, writing, analysis, creativity, learning, general

    var title: String {
        switch self {
        case .coding: return "코딩 · 오류 해결"
        case .writing: return "글쓰기 · 편집"
        case .analysis: return "논리 · 비교 분석"
        case .creativity: return "기획 · 아이디어"
        case .learning: return "학습 · 설명"
        case .general: return "일반 질문"
        }
    }
    var symbol: String {
        switch self {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "pencil.line"
        case .analysis: return "chart.xyaxis.line"
        case .creativity: return "lightbulb"
        case .learning: return "graduationcap"
        case .general: return "sparkles"
        }
    }
    var provider: AIProvider {
        switch self {
        case .coding, .learning, .general: return .openai
        case .writing, .analysis: return .anthropic
        case .creativity: return .gemini
        }
    }
    var explanation: String {
        switch self {
        case .coding: return "코드와 실행 단계를 구조화하는 역할로 추천했어요."
        case .writing: return "문장 구조와 톤을 검토하는 역할로 추천했어요."
        case .analysis: return "비교 조건과 반론을 검토하는 역할로 추천했어요."
        case .creativity: return "여러 아이디어를 발산하는 역할로 추천했어요."
        case .learning: return "기초 설명과 연습 문제를 조직하는 역할로 추천했어요."
        case .general: return "요청 유형이 뚜렷하지 않아 기본 모델을 추천했어요."
        }
    }
    var systemInstruction: String {
        switch self {
        case .coding: return "당신은 실용적인 프로그래밍 도우미입니다. 전제를 밝히고 실행 가능한 예제를 제시하며, 코드를 실행하지 않았다면 실행했다고 주장하지 마세요."
        case .writing: return "당신은 정교한 글쓰기 편집자입니다. 목적과 독자를 고려하고 구체적인 개정안을 제시하세요."
        case .analysis: return "당신은 분석가입니다. 근거, 가정, 불확실성과 반론을 구분해서 답하세요."
        case .creativity: return "당신은 창의적 기획자입니다. 새로운 선택지와 구현 가능한 다음 행동을 제안하세요."
        case .learning: return "당신은 초보자 친화적인 튜터입니다. 쉬운 설명과 단계별 예시를 제시하세요."
        case .general: return "사용자의 질문에 정확하고 친절하게 답하세요. 확인하지 않은 사실은 단정하지 마세요."
        }
    }
}

struct SmartRoutingDecision {
    let task: SmartTask
    let preferred: AIProvider
    let matchedTerms: [String]

    var reasoning: String {
        let clue = matchedTerms.isEmpty ? "명확한 단서가 적어 기본 분류를 적용했어요." : "단서: \(matchedTerms.prefix(4).joined(separator: " · "))"
        return "\(task.explanation) \(clue)"
    }
}

enum SmartRouter {
    private static let dictionaries: [(SmartTask, [String])] = [
        (.coding, ["코드", "개발", "swift", "python", "java", "xcode", "컴파일", "버그", "오류", "디버", "api", "algorithm", "함수", "program", "앱 구현"]),
        (.writing, ["자소서", "소설", "이메일", "문장", "교정", "편집", "글쓰기", "작문", "보고서 작성", "초안", "번역", "에세이", "문체", "rewrite", "email"]),
        (.analysis, ["분석", "비교", "근거", "장단점", "평가", "리스크", "데이터", "통계", "전략", "의사결정", "왜", "analysis", "compare"]),
        (.creativity, ["아이디어", "창업", "기획", "브레인스토밍", "독창", "참신", "상상", "콘셉트", "발상", "creative", "brainstorm"]),
        (.learning, ["공부", "시험", "설명해", "가르쳐", "개념", "문제 풀", "학습", "토익", "예제", "초보", "이해", "teach", "explain"])
    ]
    static func recommend(_ question: String) -> SmartRoutingDecision {
        let normalized = question.lowercased()
        var bestTask: SmartTask = .general
        var bestScore = 0
        var bestTerms: [String] = []
        for (task, terms) in dictionaries {
            let matches = terms.filter { normalized.contains($0) }
            // Prefer multiple distinct cues. Ties keep stable priority order.
            let score = matches.count
            if score > bestScore {
                bestTask = task; bestScore = score; bestTerms = matches
            }
        }
        return .init(task: bestTask, preferred: bestTask.provider, matchedTerms: bestTerms)
    }
}
