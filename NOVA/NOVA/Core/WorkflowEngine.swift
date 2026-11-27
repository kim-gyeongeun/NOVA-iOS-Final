import Foundation

struct WorkflowUpdate {
    let step: Int
    let total: Int
    let label: String
    let trace: [WorkflowTrace]
}

struct WorkflowOptions {
    var reviewPass = true
    var fallbackToAvailableModel = true
    var revisionPass = false
    var acceptanceCriteria = ""
    var outputFormat = ""
}

struct WorkflowEngine {
    let service = AIService()

    /// Executes actual provider requests unless Demo Mode is enabled.
    /// Timeline events are emitted only when a model request has finished.
    func run(team: AgentTeam, goal: String, options: WorkflowOptions = .init(), progress: @escaping @MainActor (WorkflowUpdate) -> Void) async throws -> WorkflowRecord {
        guard !team.agents.isEmpty, team.agents.count <= TeamStudioRules.maximumAgents else {
            throw NovaError.server("AI 팀에는 1~5명의 에이전트가 필요합니다.")
        }
        let doRevision = options.reviewPass && options.revisionPass
        let total = team.agents.count + 2 + (options.reviewPass ? 1 : 0) + (doRevision ? 1 : 0)
        let brief = "완료 기준: \(String(options.acceptanceCriteria.prefix(700)))\n출력 형식: \(String(options.outputFormat.prefix(500)))"
        var trace: [WorkflowTrace] = []
        var fallbackUsed = false
        let available: [AIProvider]
        if service.demo {
            available = AIProvider.allCases
        } else {
            let status = try await service.health()
            available = AIProvider.allCases.filter { status.providers[$0.rawValue] == true }
            guard !available.isEmpty else {
                throw NovaError.server("LIVE 모드지만 서버에 연결된 AI API 키가 없습니다. 설정 → 서버 연결 확인 후 Backend/.env를 설정하세요.")
            }
        }
        func choose(_ wanted: AIProvider) throws -> AIProvider {
            if available.contains(wanted) { return wanted }
            if options.fallbackToAvailableModel, let first = available.first {
                return first
            }
            throw NovaError.server("\(wanted.title) API 키가 연결되지 않았습니다. 다른 AI를 선택하거나 '연결된 모델로 대체'를 켜세요.")
        }
        func update(_ step: Int, _ label: String) async {
            await progress(WorkflowUpdate(step: step, total: total, label: label, trace: trace))
        }
        func execute(_ wanted: AIProvider, stage: String, step: Int, message: String, system: String) async throws -> String {
            let provider = try choose(wanted)
            if provider != wanted { fallbackUsed = true }
            await update(step, "\(stage) · \(provider.title) 실행 중")
            try Task.checkCancellation()
            let start = Date()
            let output = try await service.ask(provider, message: message, system: system)
            try Task.checkCancellation()
            trace.append(WorkflowTrace(stage: stage, model: provider.title,
                seconds: Date().timeIntervalSince(start), output: output, demo: service.demo))
            await update(step + 1, "\(stage) 완료")
            return output
        }

        await update(0, "AI 실행 계획 준비")
        let planner = try await execute(.openai, stage: "매니저 · 작업 계획", step: 0,
            message: "목표: \(goal)\n\(brief)\n다음 에이전트 역할을 고려해 구체적인 실행 순서와 확인 기준을 설계해줘: \(team.agents.map(\.name).joined(separator: ", "))",
            system: "너는 작업 분해 매니저야. 실제 수행하지 않은 외부 조사를 했다고 말하지 마.")
        var results: [AgentResult] = []
        for (index, agent) in team.agents.enumerated() {
            try Task.checkCancellation()
            let prior = results.map { "\($0.name): \(String($0.output.prefix(1600)))" }.joined(separator: "\n\n")
            let output = try await execute(agent.provider, stage: agent.name, step: index + 1,
                message: "공통 목표: \(goal)\n\(brief)\n\n매니저 계획:\n\(String(planner.prefix(1800)))\n\n앞 단계의 결과:\n\(prior.isEmpty ? "아직 없음" : prior)\n\n역할에 해당하는 구체적인 산출물을 작성해줘.",
                system: "당신은 \(agent.name) 역할의 AI 에이전트입니다. \(agent.instruction) 검증하지 않은 내용을 사실이라고 주장하지 마세요.")
            results.append(AgentResult(name: agent.name, provider: try choose(agent.provider), output: output))
        }
        let combined = results.map { "### \($0.name)\n\(String($0.output.prefix(2400)))" }.joined(separator: "\n\n")
        var review: String? = nil
        if options.reviewPass {
            review = try await execute(.openai, stage: "QA · 교차 검토", step: team.agents.count + 1,
                message: "원래 목표: \(goal)\n\(brief)\n\n각 AI 결과:\n\(combined)\n\n서로 모순되는 내용, 근거 부족, 실행 위험, 누락 조건을 구분하고 반드시 고쳐야 할 내용과 좋은 점을 제시해.",
                system: "너는 품질 검토자야. AI 모델의 합의만으로 주장이 검증되었다고 하지 마. 웹 검색과 코드 실행을 수행하지 않았음을 명시해.")
        }
        var revision: String? = nil
        if doRevision, let review {
            revision = try await execute(.openai, stage: "Revision · QA 반영", step: team.agents.count + 2,
                message: "목표: \(goal)\n\(brief)\n\n팀 결과:\n\(combined)\n\nQA 지적:\n\(review)\n\n이 지적을 반영해 수정된 초안을 작성하고, 아직 검증할 수 없는 사항을 별도 표시해줘.",
                system: "너는 수정 담당 에이전트야. 실제 실행이나 외부 검색을 하지 않았다면 하지 않았다고 명시해.")
        }
        let summary = try await execute(.openai, stage: "NOVA · 최종 통합", step: total - 1,
            message: "목표: \(goal)\n\(brief)\n\n팀 결과:\n\(combined)\n\n\(review.map { "QA 검토:\n\($0)" } ?? "추가 검토 없음")\n\n\(revision.map { "수정 초안:\n\($0)" } ?? "수정 라운드 없음")\n\n앞선 결과를 통합하고 QA 지적을 반영해 실천 단계와 검증 필요 사항을 구분한 최종 보고서를 한국어로 작성해줘.",
            system: "너는 최종 편집자야. 검증하지 않은 내용은 '미검증'으로 표기하고, 한계를 명확하게 알려줘.")
        await update(total, "완료 · \(trace.count)개 작업 기록")
        return WorkflowRecord(title: team.name, goal: goal, results: results, summary: summary,
            demo: service.demo, trace: trace, review: review, fallbackUsed: fallbackUsed, revision: revision)
    }

    func compare(question: String) async -> Comparison {
        // Every provider is independently requested, even in demo mode.
        return await withTaskGroup(of: CompareAnswer.self) { group in
            for provider in AIProvider.allCases {
                group.addTask {
                    do { return CompareAnswer(provider: provider, text: try await service.ask(provider, message: question)) }
                    catch { return CompareAnswer(provider: provider, text: "", error: error.localizedDescription) }
                }
            }
            var answers: [CompareAnswer] = []
            for await answer in group { answers.append(answer) }
            answers.sort { AIProvider.allCases.firstIndex(of: $0.provider)! < AIProvider.allCases.firstIndex(of: $1.provider)! }
            return Comparison(question: question, answers: answers)
        }
    }

    func debate(topic: String, first: AIProvider, second: AIProvider, progress: @escaping @MainActor (String) -> Void) async throws -> DebateRecord {
        guard first != second else { throw NovaError.server("다른 AI 모델 두 개를 선택하세요.") }
        await progress("1라운드 · 서로 다른 관점 만들기")
        async let openingA = service.ask(first, message: "주제: \(topic)\n찬성하는 입장에서 근거 3가지와 전제를 제시해 줘.", system: "토론 에이전트 A. 모르는 사실은 추측이라고 명시.")
        async let openingB = service.ask(second, message: "주제: \(topic)\n반대하거나 우려하는 입장에서 근거 3가지와 전제를 제시해 줘.", system: "토론 에이전트 B. 모르는 사실은 추측이라고 명시.")
        let (a, b) = try await (openingA, openingB)
        await progress("2라운드 · 상대 논리 검토")
        async let rebuttalA = service.ask(first, message: "주제: \(topic)\n상대 입장: \(b)\n이 주장의 약점을 공정하게 검토하고 타당한 부분도 인정해 줘.")
        async let rebuttalB = service.ask(second, message: "주제: \(topic)\n상대 입장: \(a)\n이 주장의 약점을 공정하게 검토하고 타당한 부분도 인정해 줘.")
        let (ra, rb) = try await (rebuttalA, rebuttalB)
        await progress("최종 · 쟁점 정리")
        let summary = try await service.ask(.openai, message: "주제: \(topic)\nA 주장: \(a)\nB 주장: \(b)\nA 반박: \(ra)\nB 반박: \(rb)\n\n중립적으로 합의점, 이견, 검증 필요한 주장을 분리해 줘. 다수 모델의 합의가 사실 입증은 아니라고 명시해.")
        return DebateRecord(topic: topic, first: first, second: second, openingA: a, openingB: b, rebuttalA: ra, rebuttalB: rb, conclusion: summary)
    }
}
