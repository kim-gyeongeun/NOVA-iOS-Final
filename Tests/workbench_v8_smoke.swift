import Foundation

// Run this file with Core/Models.swift and WorkbenchModels.swift; only
// Apple UI/PDF types are stubbed for Linux-side model testing.
struct PageText: Codable { var pageNumber: Int; var text: String }
struct DocumentInsight: Codable {
    var id = UUID()
    var title: String
    var pages: [PageText]
    var prompt: String
    var analysis: String
    var demo: Bool
    var createdAt = Date()
}
enum DocumentReader {
    static func makeEvidence(_ pages: [PageText]) -> String {
        pages.map { "[P\($0.pageNumber)-L1] \($0.text)" }.joined(separator: "\n")
    }
}

@main struct WorkbenchSmoke {
    static func main() throws {
        let oldJSON = """
        {"rooms":[],"teams":[],"comparisons":[],"workflows":[],"debates":[],"completedMissions":0}
        """.data(using: .utf8)!
        let old = try JSONDecoder().decode(PersistedData.self, from: oldJSON)
        precondition(old.workbenchReports == nil, "Old data must decode with nil workbenchReports")
        let wf = WorkflowRecord(title: "기획 프로젝트", goal: "AI 앱 기획", results: [AgentResult(name: "개발자", provider: .openai, output: "SwiftUI")], summary: "계획 수립", demo: true)
        let cmp = Comparison(question: "어떤 앱?", answers: [CompareAnswer(provider: .gemini, text: "메모", error: nil)])
        var updated = old
        updated.workflows = [wf]
        updated.comparisons = [cmp]
        let sources = WorkbenchLibrary.available(from: updated)
        precondition(sources.count == 2)
        precondition(sources.first?.provenance == "unknown")
        let report = WorkbenchLibrary.fresh(title: " 테스트 보고서 ", kind: "프로젝트 보고서", sources: sources)
        precondition(report.title == "테스트 보고서")
        precondition(report.includesDemo)
        precondition(report.hasUnknownProvenance)
        precondition(report.markdown.contains("DEMO"))
        precondition(report.markdown.contains("[S1]"))
        precondition(WorkbenchLibrary.aiPrompt(for: report, userInstruction: "요약").contains("<reference_material>"))
        precondition(WorkbenchLibrary.reviewPrompt(for: report).contains("<draft>"))
        updated.workbenchReports = [report]
        let output = try JSONEncoder().encode(updated)
        let restored = try JSONDecoder().decode(PersistedData.self, from: output)
        precondition(restored.workbenchReports?.first?.sources.count == 2)
        precondition(restored.workbenchReports?.first?.title == "테스트 보고서")
        print("NOVA 8 model / legacy persistence / export tests PASS")
    }
}
