import Foundation
import Vision
import PDFKit
import UIKit

// The OCR engine is fully on-device. No document data is sent to the server
// until the user explicitly presses an AI analysis button.
struct PageText: Identifiable, Codable {
    var id = UUID()
    var pageNumber: Int
    var text: String
}

struct DocumentInsight: Identifiable, Codable {
    var id = UUID()
    var title: String
    var sourceType: String
    var pages: [PageText]
    var prompt: String
    var analysis: String
    var provider: AIProvider
    var demo: Bool
    var createdAt = Date()

    var shareText: String {
        "# \(title)\n\nAI: \(provider.title)\n분석 모드: \(demo ? "데모" : "실제 API")\n\n## 요청\n\(prompt)\n\n## 분석 결과\n\(analysis)\n\n## OCR 추출 내용\n" +
        pages.map { "### 페이지 \($0.pageNumber)\n\($0.text)" }.joined(separator: "\n\n")
    }
}

enum DocumentReader {
    static let maximumPages = 8
    static let maximumCharacters = 24_000

    static func extractText(from jpegData: Data) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.recognitionLanguages = ["ko-KR", "en-US"]
                    request.usesLanguageCorrection = true
                    try VNImageRequestHandler(data: jpegData, options: [:]).perform([request])
                    let output = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: output.joined(separator: "\n"))
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    @MainActor static func pagesFromPDF(_ url: URL) async throws -> [PageText] {
        guard let document = PDFDocument(url: url) else { throw NovaError.server("PDF를 읽을 수 없어요.") }
        guard document.pageCount > 0 else { throw NovaError.server("내용이 없는 PDF입니다.") }
        var pages: [PageText] = []
        let count = min(document.pageCount, maximumPages)
        for index in 0..<count {
            guard let page = document.page(at: index) else { continue }
            var text = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count < 30 {
                let size = page.bounds(for: .mediaBox).size
                let scale = min(2.0, 1600.0 / max(size.width, size.height, 1))
                let thumbnail = page.thumbnail(of: CGSize(width: max(size.width * scale, 1), height: max(size.height * scale, 1)), for: .mediaBox)
                if let imageData = thumbnail.jpegData(compressionQuality: 0.75) {
                    let recognized = try await extractText(from: imageData)
                    if recognized.count > text.count { text = recognized }
                }
            }
            pages.append(PageText(pageNumber: index+1, text: String(text.prefix(6000))))
        }
        return pages
    }

    static func makeEvidence(_ pages: [PageText]) -> String {
        var rows: [String] = []
        for page in pages {
            for (idx, line) in page.text.components(separatedBy: .newlines).enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { rows.append("[P\(page.pageNumber)-L\(idx + 1)] \(trimmed)") }
            }
        }
        return String(rows.joined(separator: "\n").prefix(maximumCharacters))
    }
}
