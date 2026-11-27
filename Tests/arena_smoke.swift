import Foundation

@main struct ArenaSmoke {
    static func main() throws {
        let a = ArenaAnswer(provider: .openai, text: "a", error: nil)
        let b = ArenaAnswer(provider: .anthropic, text: "b", error: nil)
        var first = ArenaMatch(prompt: "test", left: a, right: b, demo: false)
        first.vote = .left
        var second = ArenaMatch(prompt: "tie", left: a, right: b, demo: false)
        second.vote = .tie
        var demo = ArenaMatch(prompt: "demo", left: b, right: a, demo: true)
        demo.vote = .left
        let live = ArenaStats.scores(matches: [first, second, demo], includeDemo: false)
        let gpt = live.first { $0.provider == .openai }!
        precondition(gpt.wins == 1 && gpt.appearances == 2 && gpt.percentage == 50)
        let all = ArenaStats.scores(matches: [first, second, demo], includeDemo: true)
        precondition(all.first { $0.provider == .anthropic }!.wins == 1)

        // An older local save contains no arenaMatches key, which must decode as nil.
        let old = """
        {"rooms":[],"teams":[],"comparisons":[],"workflows":[],"debates":[],"completedMissions":4}
        """
        let restored = try JSONDecoder().decode(PersistedData.self, from: Data(old.utf8))
        precondition(restored.completedMissions == 4 && restored.arenaMatches == nil)
        print("Arena scores + legacy saves: PASS")
    }
}
