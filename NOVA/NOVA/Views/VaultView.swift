import SwiftUI

struct VaultView: View {
    @EnvironmentObject private var store: NovaStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                SectionCaption(title: "내 작업", subtitle: "대화와 협업 결과를 한곳에서 관리하세요")
                HStack(spacing: 10) {
                    stat("대화", count: store.data.rooms.count, icon: "bubble.left")
                    stat("비교", count: store.data.comparisons.count, icon: "rectangle.split.3x1")
                    stat("협업", count: store.data.workflows.count, icon: "person.3")
                }
                NavigationLink(destination: WorkbenchView()) {
                    GlassPanel {
                        HStack {
                            Image(systemName: "doc.text.image").foregroundStyle(NovaStyle.cyan)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("보고서 작업실").font(.headline)
                                Text("편집 가능한 보고서 \((store.data.workbenchReports ?? []).count)개 · Markdown 출력")
                                    .font(.caption).foregroundStyle(NovaStyle.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                }.buttonStyle(.plain)
                if let docs = store.data.documentInsights, !docs.isEmpty {
                    SectionCaption(title: "문서 분석 기록", subtitle: "OCR 원문과 AI 분석 결과")
                    ForEach(docs) { doc in
                        NavigationLink(destination: DocumentInsightHistoryView(insight: doc)) {
                            GlassPanel {
                                HStack {
                                    Image(systemName: "doc.text.viewfinder").foregroundStyle(NovaStyle.cyan)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(doc.title).font(.headline).lineLimit(1)
                                        Text("\(doc.prompt) · \(doc.provider.title) · \(doc.demo ? "DEMO" : "LIVE")")
                                            .font(.caption).foregroundStyle(NovaStyle.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(NovaStyle.muted)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                }
                NavigationLink(destination: ArenaHistoryView()) {
                    GlassPanel {
                        HStack {
                            Image(systemName: "eye.slash.fill").foregroundStyle(NovaStyle.cyan)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("블라인드 평가").font(.headline)
                                Text("내 투표 기록 \((store.data.arenaMatches ?? []).count)개 · 모델별 승률 보기")
                                    .font(.caption).foregroundStyle(NovaStyle.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                }.buttonStyle(.plain)
                if store.data.comparisons.isEmpty && store.data.workflows.isEmpty && store.data.debates.isEmpty {
                    GlassPanel { Text("AI 도구나 협업에서 결과를 만들면 여기에 저장돼요.").foregroundStyle(NovaStyle.muted) }
                }
                if !store.data.workflows.isEmpty { SectionCaption(title: "AI 팀 결과", subtitle: "에이전트 별 결과 + 최종 보고서") }
                ForEach(store.data.workflows) { workflow in
                    NavigationLink(destination: WorkflowHistoryView(record: workflow)) {
                        GlassPanel {
                            HStack {
                                Image(systemName: "person.3.fill").foregroundStyle(NovaStyle.cyan)
                                VStack(alignment: .leading) {
                                    Text(workflow.title).font(.headline)
                                    Text(workflow.goal).font(.caption).lineLimit(2).foregroundStyle(NovaStyle.muted)
                                }
                                Spacer(); Image(systemName: "chevron.right")
                            }
                        }
                    }.buttonStyle(.plain)
                }
                Group {
                if !store.data.comparisons.isEmpty { SectionCaption(title: "AI 비교 기록", subtitle: "과거 질문과 모델 응답") }
                ForEach(store.data.comparisons) { comparison in
                    NavigationLink(destination: ComparisonHistoryView(comparison: comparison)) {
                        GlassPanel {
                            HStack {
                                Image(systemName: "rectangle.split.3x1.fill").foregroundStyle(NovaStyle.cyan)
                                Text(comparison.question).lineLimit(2)
                                Spacer(); Image(systemName: "chevron.right")
                            }
                        }
                    }.buttonStyle(.plain)
                }
                if !store.data.debates.isEmpty { SectionCaption(title: "AI 토론 기록", subtitle: "주장과 반박, 최종 정리") }
                ForEach(store.data.debates) { debate in
                    NavigationLink(destination: DebateHistoryView(debate: debate)) {
                        GlassPanel {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(NovaStyle.cyan)
                                Text(debate.topic).lineLimit(2)
                                Spacer(); Image(systemName: "chevron.right")
                            }
                        }
                    }.buttonStyle(.plain)
                }
                }
            }.padding(18)
        }.navigationTitle("보관함").novaScreen()
    }
    private func stat(_ name: String, count: Int, icon: String) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: icon).foregroundStyle(NovaStyle.cyan)
                Text("\(count)").font(.title2.weight(.semibold))
                Text(name).font(.caption).foregroundStyle(NovaStyle.muted)
            }
        }
    }
}

struct WorkflowHistoryView: View {
    let record: WorkflowRecord
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(title: record.title, subtitle: record.goal)
                if record.demo { Text("DEMO 기록 · 실제 AI 결과가 아닙니다.").font(.footnote).foregroundStyle(.orange) }
                if let trace = record.trace, !trace.isEmpty {
                    WorkflowTimelineView(trace: trace)
                }
                if record.fallbackUsed == true {
                    Text("연결된 다른 모델로 일부 역할 대체됨").font(.caption).foregroundStyle(.orange)
                }
                ReadOnlyReport(title: "통합 보고서", text: record.summary)
                if let review = record.review { ReadOnlyReport(title: "QA 검토", text: review) }
                ShareLink(item: record.summary) { Label("통합 보고서 공유", systemImage: "square.and.arrow.up") }
                ForEach(record.results) { result in ReadOnlyReport(title: result.name, text: result.output) }
            }.padding(18)
        }.navigationTitle("협업 기록").novaScreen()
    }
}

struct ComparisonHistoryView: View {
    let comparison: Comparison
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(title: "질문", subtitle: comparison.question)
                ForEach(comparison.answers) { answer in
                    if let error = answer.error { ErrorBanner(text: error) }
                    else { ReadOnlyReport(title: answer.provider.title, text: answer.text) }
                }
                if let synthesis = comparison.synthesis { ReadOnlyReport(title: "NOVA FUSION", text: synthesis) }
            }.padding(18)
        }.navigationTitle("비교 기록").novaScreen()
    }
}

struct DebateHistoryView: View {
    let debate: DebateRecord
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionCaption(title: "토론 주제", subtitle: debate.topic)
                ReadOnlyReport(title: "찬성 · \(debate.first.title)", text: debate.openingA)
                ReadOnlyReport(title: "반대 · \(debate.second.title)", text: debate.openingB)
                ReadOnlyReport(title: "찬성 측 반박", text: debate.rebuttalA)
                ReadOnlyReport(title: "반대 측 반박", text: debate.rebuttalB)
                ReadOnlyReport(title: "최종 쟁점", text: debate.conclusion)
            }.padding(18)
        }.navigationTitle("토론 기록").novaScreen()
    }
}


struct DocumentInsightHistoryView: View {
    let insight: DocumentInsight
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                SectionCaption(title: insight.title, subtitle: "\(insight.provider.title) · \(insight.prompt) · \(insight.demo ? "데모 응답" : "AI 분석")")
                ReadOnlyReport(title: "분석 결과", text: insight.analysis)
                ShareLink(item: insight.shareText) { Label("분석 내용 공유", systemImage: "square.and.arrow.up") }
                DisclosureGroup("원문 OCR 보기") {
                    Text(DocumentReader.makeEvidence(insight.pages))
                        .font(.caption.monospaced()).textSelection(.enabled)
                }
            }.padding(18)
        }.navigationTitle("문서 분석 기록").novaScreen()
    }
}
