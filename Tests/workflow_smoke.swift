import Foundation

@main struct WorkflowSmoke {
    static func main() async throws {
        UserDefaults.standard.set(true, forKey: "demoMode")
        let team = AgentTeam(name: "테스트 팀", goal: "협업 검증", agents: [
            Agent(name: "기획자", provider: .openai, instruction: "기획"),
            Agent(name: "검토자", provider: .gemini, instruction: "검토")
        ])
        let result = try await WorkflowEngine().run(team: team, goal: "기능을 계획해줘") { _ in }
        assert(result.demo)
        assert(result.results.count == 2)
        assert(result.trace?.count == 5) // manager + 2 agents + QA + synthesis
        assert(result.review != nil)
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(WorkflowRecord.self, from: data)
        assert(decoded.trace?.count == 5)
        let noReview = try await WorkflowEngine().run(team: team, goal: "기능을 계획해줘",
            options: .init(reviewPass: false, fallbackToAvailableModel: true)) { _ in }
        assert(noReview.trace?.count == 4)
        assert(noReview.review == nil)
        // Legacy NOVA 2.0 saved records did not contain the optional fields.
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "trace")
        json.removeValue(forKey: "review")
        json.removeValue(forKey: "fallbackUsed")
        let legacy = try JSONSerialization.data(withJSONObject: json)
        let backward = try JSONDecoder().decode(WorkflowRecord.self, from: legacy)
        assert(backward.trace == nil)
        print("OK: workflow timeline, QA toggle, backward-compatible records")
    }
}
