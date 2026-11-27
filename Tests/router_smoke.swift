import Foundation

@main struct RouterSmoke {
    static func main() {
        let testCases: [(String, SmartTask)] = [
            ("SwiftUI 컴파일 오류를 수정해 줘", .coding),
            ("교수님께 보낼 이메일 문장 편집해 줘", .writing),
            ("데이터 비교 분석과 근거를 보여 줘", .analysis),
            ("AI 창업 아이디어를 독창적으로 기획해 줘", .creativity),
            ("토익 초보 개념을 설명해 줘", .learning),
            ("안녕하세요", .general)
        ]
        for (prompt, expected) in testCases {
            let actual = SmartRouter.recommend(prompt)
            precondition(actual.task == expected, "Expected \(expected) for \(prompt), got \(actual.task)")
            precondition(actual.preferred == expected.provider)
            print("✓ \(actual.task.title) → \(actual.preferred.title)")
        }
        print("SmartRouter: 6/6 checks passed")
    }
}
