import Foundation

@main struct StudioV5Smoke {
    static func main() async throws {
        var team = AgentTeam(name: "리뷰팀", goal: "품질 향상", agents: [
            Agent(name: "기획", provider: .openai, instruction: "요구사항 설계"),
            Agent(name: "검토", provider: .gemini, instruction: "위험 분석")
        ])
        assert(TeamStudioRules.validate(name: team.name, agents: team.agents) == nil)
        assert(TeamStudioRules.validate(name: " ", agents: team.agents) != nil)
        assert(TeamStudioRules.validate(name: team.name, agents: []) != nil)
        let copied = TeamStudioRules.duplicated(team)
        assert(copied.id != team.id)
        assert(copied.agents.map(\.id) != team.agents.map(\.id))
        assert(copied.agents.map(\.instruction) == team.agents.map(\.instruction))
        team.agents.swapAt(0, 1)
        assert(team.agents[0].name == "검토")

        UserDefaults.standard.set(true, forKey: "demoMode")
        let options = WorkflowOptions(reviewPass: true, fallbackToAvailableModel: true,
            revisionPass: true, acceptanceCriteria: "이슈 3개와 우선순위 제시",
            outputFormat: "문제→해결 방안→검증 사항")
        let record = try await WorkflowEngine().run(team: team, goal: "앱 기획안을 점검해줘", options: options) { _ in }
        assert(record.demo)
        assert(record.trace?.count == team.agents.count + 4)
        assert(record.revision != nil)
        assert(record.review != nil)
        let report = WorkflowExporter.markdown(record)
        assert(report.contains("QA 검토") && report.contains("개선 초안") && report.contains("DEMO"))
        let encoded = try JSONEncoder().encode(record)
        var json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        json.removeValue(forKey: "revision")
        let oldRecord = try JSONDecoder().decode(WorkflowRecord.self, from: JSONSerialization.data(withJSONObject: json))
        assert(oldRecord.revision == nil)
        let noReview = try await WorkflowEngine().run(team: team, goal: "체크리스트", options:
            .init(reviewPass: false, fallbackToAvailableModel: true, revisionPass: true)) { _ in }
        assert(noReview.revision == nil)
        assert(noReview.trace?.count == team.agents.count + 2)
        print("OK: team copy, validation, order, QA revision, markdown, legacy persistence")
    }
}
