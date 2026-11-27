import Foundation

/// Two model calls start concurrently. Model labels are only disclosed by the UI after a vote.
struct ArenaEngine {
    func play(prompt: String, providerA: AIProvider, providerB: AIProvider) async -> ArenaMatch {
        // Shuffle display position before issuing requests, without modifying the models used.
        let leftProvider = Bool.random() ? providerA : providerB
        let rightProvider = leftProvider == providerA ? providerB : providerA
        let demo = AIService().demo
        async let lhs = askSafely(leftProvider, prompt: prompt)
        async let rhs = askSafely(rightProvider, prompt: prompt)
        let (left, right) = await (lhs, rhs)
        return ArenaMatch(prompt: prompt, left: left, right: right, demo: demo)
    }

    private func askSafely(_ provider: AIProvider, prompt: String) async -> ArenaAnswer {
        do {
            let answer = try await AIService().ask(provider, message: prompt)
            return ArenaAnswer(provider: provider, text: answer, error: nil)
        } catch {
            return ArenaAnswer(provider: provider, text: "", error: error.localizedDescription)
        }
    }
}
