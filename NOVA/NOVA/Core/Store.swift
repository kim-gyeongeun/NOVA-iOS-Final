import Foundation
import Combine

@MainActor final class NovaStore: ObservableObject {
    @Published var data: PersistedData { didSet { save() } }
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("nova-v1.json")
        if let raw = try? Data(contentsOf: fileURL), let restored = try? JSONDecoder().decode(PersistedData.self, from: raw) {
            data = restored
        } else { data = PersistedData() }
    }
    private func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }
    func addRoom(_ provider: AIProvider) -> UUID {
        let room = ChatRoom(provider: provider)
        data.rooms.insert(room, at: 0)
        return room.id
    }
    func updateRoom(_ room: ChatRoom) {
        guard let index = data.rooms.firstIndex(where: { $0.id == room.id }) else { return }
        var copy = data
        copy.rooms[index] = room
        copy.rooms.sort { $0.updatedAt > $1.updatedAt }
        data = copy
    }
    func deleteRooms(at offsets: IndexSet) { data.rooms.remove(atOffsets: offsets) }
    func deleteRoom(_ id: UUID) {
        data.rooms.removeAll { $0.id == id }
    }
    func addTeam(_ team: AgentTeam) { data.teams.insert(team, at: 0) }
    func deleteTeam(_ id: UUID) { data.teams.removeAll { $0.id == id } }
    func updateTeam(_ team: AgentTeam) {
        guard let index = data.teams.firstIndex(where: { $0.id == team.id }) else { return }
        data.teams[index] = team
    }
    func duplicateTeam(_ id: UUID) {
        guard let team = data.teams.first(where: { $0.id == id }) else { return }
        data.teams.insert(TeamStudioRules.duplicated(team), at: 0)
    }
    func saveComparison(_ result: Comparison) {
        if let index = data.comparisons.firstIndex(where: { $0.id == result.id }) { data.comparisons[index] = result }
        else { data.comparisons.insert(result, at: 0) }
    }
    func saveWorkflow(_ result: WorkflowRecord) { data.workflows.insert(result, at: 0) }
    func saveDebate(_ result: DebateRecord) { data.debates.insert(result, at: 0) }
    func saveArenaMatch(_ match: ArenaMatch) {
        guard match.vote != nil && match.isPlayable else { return }
        var copy = data
        var matches = copy.arenaMatches ?? []
        if !matches.contains(where: { $0.id == match.id }) { matches.insert(match, at: 0) }
        copy.arenaMatches = matches
        data = copy
    }
    func clearArenaMatches() {
        var copy = data
        copy.arenaMatches = []
        data = copy
    }
    func saveDocumentInsight(_ report: DocumentInsight) {
        var copy = data
        var insights = copy.documentInsights ?? []
        insights.insert(report, at: 0)
        copy.documentInsights = Array(insights.prefix(60))
        data = copy
    }
    func deleteDocumentInsight(_ id: UUID) {
        var copy = data
        copy.documentInsights?.removeAll { $0.id == id }
        data = copy
    }
    func saveWorkbenchReport(_ report: WorkbenchReport, note: String = "사용자 편집") {
        var copy = data
        var items = copy.workbenchReports ?? []
        var next = report
        if let index = items.firstIndex(where: { $0.id == report.id }) {
            let old = items[index]
            if old.body != report.body || old.title != report.title {
                next.revisions = Array((old.revisions + [WorkbenchRevision(body: old.body, title: old.title, note: note)]).suffix(20))
            } else { next.revisions = old.revisions }
            next.createdAt = old.createdAt
            next.updatedAt = Date()
            items[index] = next
        } else { items.insert(next, at: 0) }
        copy.workbenchReports = items.sorted { $0.updatedAt > $1.updatedAt }
        data = copy
    }
    func deleteWorkbenchReport(_ id: UUID) {
        var copy = data
        copy.workbenchReports?.removeAll { $0.id == id }
        data = copy
    }
    func missionCompleted() { data.completedMissions += 1 }
}
