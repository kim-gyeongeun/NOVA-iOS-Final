import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct ServerTurn: Codable, Sendable { let role: String; let content: String }
struct AIRequest: Encodable, Sendable {
    let provider: String
    let messages: [ServerTurn]
    let system: String?
    let image_base64: String?
}
struct AIResponse: Decodable { let provider: String; let text: String; let model: String; let demo: Bool }
struct ServerStatus: Decodable { let name: String; let providers: [String: Bool] }
struct ProviderConnection: Decodable, Identifiable {
    let id: String
    let configured: Bool
    let model: String
}
struct ProviderConnectionList: Decodable { let providers: [ProviderConnection] }
struct ConnectionProbe: Decodable {
    let provider: String
    let model: String
    let elapsed_ms: Int
    let success: Bool
    let preview: String
}

private struct ServerError: Decodable { let detail: String }

struct AIService: Sendable {
    var demo: Bool { UserDefaults.standard.object(forKey: "demoMode") as? Bool ?? true }
    var serverURL: String { UserDefaults.standard.string(forKey: "serverURL") ?? "http://127.0.0.1:8765" }

    func ask(_ provider: AIProvider, message: String, history: [ChatTurn] = [], system: String? = nil, imageBase64: String? = nil) async throws -> String {
        if demo { return DemoBrain.answer(provider: provider, prompt: message, system: system) }
        let old = history.suffix(12).map { ServerTurn(role: $0.role == "assistant" ? "assistant" : "user", content: $0.text) }
        let payload = AIRequest(provider: provider.rawValue, messages: old + [.init(role: "user", content: message)], system: system, image_base64: imageBase64)
        guard let url = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines) + "/v1/chat") else { throw NovaError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NovaError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "서버 오류"
            throw NovaError.server("HTTP \(http.statusCode): \(body.prefix(350))")
        }
        return try JSONDecoder().decode(AIResponse.self, from: data).text
    }

    private func endpoint(_ path: String) throws -> URL {
        let base = serverURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + path), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else { throw NovaError.invalidURL }
        return url
    }

    func health() async throws -> ServerStatus {
        let (data, response) = try await URLSession.shared.data(from: endpoint("/health"))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw NovaError.invalidResponse }
        return try JSONDecoder().decode(ServerStatus.self, from: data)
    }

    func connections() async throws -> [ProviderConnection] {
        let (data, response) = try await URLSession.shared.data(from: endpoint("/v1/providers"))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw NovaError.invalidResponse }
        return try JSONDecoder().decode(ProviderConnectionList.self, from: data).providers
    }

    /// Always performs a real model request, independent of demo mode.
    func probe(_ provider: AIProvider) async throws -> ConnectionProbe {
        let url = try endpoint("/v1/probe/" + provider.rawValue)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NovaError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(ServerError.self, from: data))?.detail ?? "서버 응답에 문제가 있습니다."
            throw NovaError.server("HTTP \(http.statusCode): \(detail)")
        }
        return try JSONDecoder().decode(ConnectionProbe.self, from: data)
    }
}

enum NovaError: LocalizedError {
    case invalidURL, invalidResponse, server(String)
    var errorDescription: String? {
        switch self { case .invalidURL: return "서버 주소가 잘못되었습니다. 설정을 확인하세요."
        case .invalidResponse: return "서버 응답을 읽을 수 없습니다."
        case .server(let message): return message }
    }
}

enum DemoBrain {
    static func answer(provider: AIProvider, prompt: String, system: String? = nil) -> String {
        let task = String(prompt.prefix(130))
        let focus: String
        switch provider {
        case .openai: focus = "실행 가능한 구조와 우선순위를 중심으로 생각해 볼게요."
        case .anthropic: focus = "사용자의 맥락과 놓친 조건을 먼저 확인해 볼게요."
        case .gemini: focus = "여러 가능성을 비교하며 대안을 탐색해 볼게요."
        }
        let agentInfo = system.map { "\n\n배정된 역할: \(String($0.prefix(110)))" } ?? ""
        return "[DEMO · \(provider.title)]\n\n요청: \(task)\n\n\(focus)\n\n1. 목표를 명확히 정의합니다.\n2. 필요한 입력 자료와 제약을 목록화합니다.\n3. 작은 작업 단위로 나누어 검증합니다.\n4. 결과를 비교하고 다음 단계를 선택합니다.\n\n이 내용은 기능을 둘러보기 위한 예시 응답입니다. 실제 모델 답변이 아닙니다. 설정에서 실사용 모드로 바꾸고 서버 API 키를 연결하면 실제 AI 결과가 표시됩니다.\(agentInfo)"
    }
}
