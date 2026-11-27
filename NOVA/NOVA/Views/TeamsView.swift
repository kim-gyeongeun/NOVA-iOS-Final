import SwiftUI

struct TeamsView: View {
    @EnvironmentObject private var store: NovaStore
    @State private var showBuilder = false
    @State private var teamToEdit: AgentTeam?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("AI 팀 스튜디오")
                        .font(.system(.title2, design: .default, weight: .bold))
                        .foregroundStyle(NovaStyle.ink)
                    Text("각 AI에게 역할을 맡기고 하나의 결과를 완성하세요.")
                        .font(.subheadline)
                        .foregroundStyle(NovaStyle.muted)
                }

                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 13) {
                        NovaFeatureIcon(symbol: "person.3.sequence.fill", size: 50)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("내 AI 팀 구성하기")
                                .font(.headline)
                                .foregroundStyle(NovaStyle.ink)
                            Text("모델과 역할을 조합해 협업을 시작하세요")
                                .font(.footnote)
                                .foregroundStyle(NovaStyle.muted)
                        }
                    }
                    PrimaryAction("새 팀 만들기", icon: "plus") { showBuilder = true }
                }
                .padding(17)
                .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(NovaStyle.stroke, lineWidth: 1))

                NavigationLink(destination: TeamGalleryView()) {
                    HStack(spacing: 13) {
                        NovaFeatureIcon(symbol: "square.grid.2x2", tint: NovaStyle.ink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("추천 팀 템플릿")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NovaStyle.ink)
                            Text("목적에 맞는 구성을 바로 불러오기")
                                .font(.footnote).foregroundStyle(NovaStyle.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(NovaStyle.muted)
                    }
                    .padding(15)
                    .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(NovaStyle.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        SectionCaption(title: "내 팀", subtitle: "저장된 팀을 선택해 미션을 실행하세요")
                        Spacer()
                        Text("\(store.data.teams.count)개")
                            .font(.footnote).foregroundStyle(NovaStyle.muted)
                    }
                    if store.data.teams.isEmpty {
                        GlassPanel {
                            Text("아직 등록된 팀이 없어요. 템플릿으로 시작할 수도 있어요.")
                                .font(.subheadline).foregroundStyle(NovaStyle.muted)
                        }
                    }
                    ForEach(store.data.teams) { team in
                        NavigationLink(destination: RunTeamView(teamID: team.id)) {
                            VStack(alignment: .leading, spacing: 13) {
                                HStack(alignment: .top, spacing: 12) {
                                    NovaFeatureIcon(symbol: "person.2", size: 45)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(team.name)
                                            .font(.headline).foregroundStyle(NovaStyle.ink)
                                        Text(team.goal)
                                            .font(.footnote).foregroundStyle(NovaStyle.muted)
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right")
                                        .font(.footnote).foregroundStyle(NovaStyle.accent)
                                }
                                HStack(spacing: 6) {
                                    ForEach(team.agents.prefix(3)) { agent in
                                        Text(agent.provider.title)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(NovaStyle.muted)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(NovaStyle.elevated, in: Capsule())
                                    }
                                    if team.agents.count > 3 {
                                        Text("+\(team.agents.count - 3)")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(NovaStyle.muted)
                                    }
                                    Spacer(minLength: 0)
                                    Text("\(team.agents.count)개 역할")
                                        .font(.caption).foregroundStyle(NovaStyle.muted)
                                }
                            }
                            .padding(16)
                            .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(NovaStyle.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { teamToEdit = team } label: { Label("팀 구성 수정", systemImage: "pencil") }
                            Button { store.duplicateTeam(team.id) } label: { Label("팀 복제", systemImage: "doc.on.doc") }
                            Button(role: .destructive) { store.deleteTeam(team.id) } label: { Label("팀 삭제", systemImage: "trash") }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("AI 협업")
        .novaScreen()
        .sheet(isPresented: $showBuilder) { TeamBuilderView() }
        .sheet(item: $teamToEdit) { team in TeamBuilderView(editingTeam: team) }
    }
}

struct TeamBuilderView: View {
    @EnvironmentObject private var store: NovaStore
    @Environment(\.dismiss) private var dismiss
    let editingTeam: AgentTeam?
    @State private var name: String
    @State private var goal: String
    @State private var agents: [Agent]
    @State private var showingError = false

    init(editingTeam: AgentTeam? = nil) {
        self.editingTeam = editingTeam
        _name = State(initialValue: editingTeam?.name ?? "나만의 AI 팀")
        _goal = State(initialValue: editingTeam?.goal ?? "복잡한 문제를 협업해서 해결")
        _agents = State(initialValue: editingTeam?.agents ?? [
            .init(name: "아이디어 전문가", provider: .openai, instruction: "다양한 가능성을 제안하고 장단점을 비교해줘."),
            .init(name: "검증 전문가", provider: .anthropic, instruction: "문제와 가정을 검토하고 개선점을 찾아줘.")
        ])
    }
    private var problem: String? { TeamStudioRules.validate(name: name, agents: agents) }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("팀 기본 정보")) {
                    TextField("팀 이름", text: $name)
                    HangulTextInput("팀 설명", text: $goal).frame(height: 68)
                }
                Section {
                    ForEach($agents) { $agent in
                        VStack(alignment: .leading, spacing: 9) {
                            TextField("역할 이름", text: $agent.name)
                            Picker("AI 모델", selection: $agent.provider) {
                                ForEach(AIProvider.allCases) { p in Text(p.title).tag(p) }
                            }
                            HangulTextInput("역할 지시문", text: $agent.instruction).frame(height: 78)
                        }.padding(.vertical, 5)
                    }.onDelete { agents.remove(atOffsets: $0) }
                     .onMove { indices, destination in agents.move(fromOffsets: indices, toOffset: destination) }
                    if agents.count < TeamStudioRules.maximumAgents {
                        Button {
                            agents.append(Agent(name: "새 역할", provider: .gemini, instruction: "요청된 문제를 다른 관점에서 분석해줘."))
                        } label: {
                            Label("에이전트 추가", systemImage: "plus")
                        }
                    }
                } header: {
                    HStack {
                        Text("AI 구성 · 최대 5명")
                        Spacer()
                        EditButton().font(.caption)
                    }
                } footer: {
                    Text("에이전트는 위에서 아래 순서로 작업합니다. ‘편집’에서 순서를 바꾸거나 삭제할 수 있어요.")
                }
                Section {
                    Text("팀을 수정해도 기존 실행 기록은 바뀌지 않습니다. LIVE 실행에는 모델별 API 요금이 발생할 수 있습니다.")
                        .font(.caption)
                }
            }.scrollContentBackground(.hidden)
                .background(NovaBackground())
                .navigationTitle(editingTeam == nil ? "AI 팀 생성" : "AI 팀 수정")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            guard problem == nil else { showingError = true; return }
                            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let saved = AgentTeam(id: editingTeam?.id ?? UUID(), name: cleanName,
                                goal: goal.trimmingCharacters(in: .whitespacesAndNewlines), agents: agents)
                            if editingTeam == nil { store.addTeam(saved) }
                            else { store.updateTeam(saved) }
                            dismiss()
                        }.disabled(problem != nil)
                    }
                }
                .alert("팀 정보를 확인하세요", isPresented: $showingError) {
                    Button("확인", role: .cancel) { }
                } message: { Text(problem ?? "내용을 확인해 주세요.") }
        }
        .preferredColorScheme(.light)
    }
}

struct RunTeamView: View {
    @EnvironmentObject private var store: NovaStore
    @AppStorage("demoMode") private var demoMode = true
    let teamID: UUID
    @State private var goal = "실생활에서 유용하면서 독창적인 AI 앱을 설계하고, 기능·화면·개발 계획을 검증해 줘."
    @State private var progress: WorkflowUpdate?
    @State private var busy = false
    @State private var record: WorkflowRecord?
    @State private var errorText: String?
    @State private var reviewPass = true
    @State private var allowFallback = true
    @State private var revisionPass = false
    @State private var blueprint: MissionBlueprint = .general
    @State private var criteria = MissionBlueprint.general.criteria
    @State private var outputFormat = MissionBlueprint.general.format
    @State private var runTask: Task<Void, Never>?
    private let sampleGoals = [
        "실생활 문제를 해결하는 AI 앱의 요구사항, 사용자 경험, 기술 설계, 위험을 종합 분석해 줘.",
        "우리 팀의 새로운 서비스를 시장·개발·디자인·리스크 관점에서 검토하고 개선해 줘.",
        "이 발표 주제에 대해 찬반 주장, 증거가 필요한 부분, 최종 발표 구조를 완성해 줘.",
        "1개월 개발 가능한 iOS 서비스를 설계하고, 우선순위별 구현 로드맵과 QA 체크리스트를 작성해 줘."
    ]
    private var team: AgentTeam? { store.data.teams.first(where: { $0.id == teamID }) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let team {
                    Group {
                    HStack {
                        SectionCaption(title: "협업 실행", subtitle: "작업 단계와 에이전트별 결과를 확인하세요")
                        Spacer()
                        Text(demoMode ? "DEMO" : "LIVE").font(.caption2.bold())
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(demoMode ? Color.orange.opacity(0.17) : Color.green.opacity(0.17), in: Capsule())
                    }
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(team.name, systemImage: "person.3.sequence.fill")
                                .font(.title3.bold()).foregroundStyle(NovaStyle.cyan)
                            Text(team.goal).font(.subheadline).foregroundStyle(NovaStyle.muted)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 7)], spacing: 7) {
                                ForEach(team.agents) { agent in
                                    Text(agent.name)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 9).padding(.vertical, 7)
                                        .background(NovaStyle.elevated, in: Capsule())
                                }
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        Button { store.duplicateTeam(team.id) } label: {
                            Label("팀 복제", systemImage: "doc.on.doc")
                        }.buttonStyle(.bordered).disabled(busy)
                        Text("팀 구성은 스튜디오 목록에서 길게 눌러 수정할 수 있어요.")
                            .font(.caption2).foregroundStyle(NovaStyle.muted)
                    }
                    SectionCaption(title: "미션 설정", subtitle: "작업별 평가 기준과 결과 형식을 설정하세요")
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("미션 유형", selection: $blueprint) {
                                ForEach(MissionBlueprint.allCases) { template in
                                    Text(template.rawValue).tag(template)
                                }
                            }.tint(NovaStyle.cyan).disabled(busy)
                            Text("완료 기준").font(.caption.bold()).foregroundStyle(NovaStyle.muted)
                            HangulTextInput("필수 조건", text: $criteria)
                                .frame(height: 78).disabled(busy)
                            Text("보고서 형식").font(.caption.bold()).foregroundStyle(NovaStyle.muted)
                            HangulTextInput("결과물 구성", text: $outputFormat)
                                .frame(height: 78).disabled(busy)
                        }
                    }
                    .onChange(of: blueprint) { newValue in
                        criteria = newValue.criteria
                        outputFormat = newValue.format
                    }
                    SectionCaption(title: "작업 목표", subtitle: "빠른 미션을 선택하거나 직접 작성하세요")
                    HangulTextInput("AI 팀에게 맡길 목표", text: $goal)
                        .frame(height: 120).padding().background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                        .disabled(busy)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sampleGoals.indices, id: \.self) { index in
                                Button("미션 \(index + 1)") { goal = sampleGoals[index] }
                                    .buttonStyle(.bordered).tint(NovaStyle.cyan).disabled(busy)
                            }
                        }
                    }
                    }
                    Group {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 11) {
                            Toggle("QA 교차 검토 추가", isOn: $reviewPass).tint(NovaStyle.cyan).disabled(busy)
                            Toggle("QA 의견 반영해 수정 초안 작성", isOn: $revisionPass)
                                .tint(NovaStyle.cyan).disabled(busy || !reviewPass)
                            Toggle("연결된 모델로 자동 대체", isOn: $allowFallback).tint(NovaStyle.cyan).disabled(busy)
                            Text("검토 결과를 반영하는 수정 라운드는 추가 AI 호출이 필요합니다. 모델 대체 시 다른 제공자로 실행될 수 있습니다.")
                                .font(.caption).foregroundStyle(NovaStyle.muted)
                            Text("예상 API 호출: \(team.agents.count + (reviewPass ? 3 : 2) + (reviewPass && revisionPass ? 1 : 0))회 · AI 사용 요금 발생 가능")
                                .font(.caption2).foregroundStyle(NovaStyle.cyan)
                        }
                    }
                    if busy {
                        Button(role: .destructive) { runTask?.cancel() } label: {
                            Label("실행 중단", systemImage: "stop.circle.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                        }.buttonStyle(.bordered)
                    } else {
                        PrimaryAction("AI 팀 실행", icon: "bolt.fill") { start(team) }
                            .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let progress {
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: busy ? "hourglass" : "checkmark.circle.fill")
                                        .foregroundStyle(NovaStyle.cyan)
                                    Text(progress.label).font(.subheadline.bold())
                                }
                                ProgressView(value: Double(progress.step), total: Double(max(progress.total, 1)))
                                    .tint(NovaStyle.cyan)
                                Text("단계 \(progress.step) / \(progress.total) · 완료된 산출물 \(progress.trace.count)개")
                                    .font(.caption).foregroundStyle(NovaStyle.muted)
                            }
                        }
                        WorkflowTimelineView(trace: progress.trace)
                    }
                    if let errorText { ErrorBanner(text: errorText) }
                    if let record {
                        if record.demo { ErrorBanner(text: "데모 실행 결과입니다. 실제 AI의 분석 결과가 아닙니다.") }
                        if record.fallbackUsed == true {
                            Text("일부 역할은 연결된 다른 AI 모델로 실행했어요.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        HStack {
                            SectionCaption(title: "최종 리포트", subtitle: "분석 결과를 확인하고 공유해 보세요")
                            Spacer()
                            ShareLink(item: record.summary) { Image(systemName: "square.and.arrow.up") }
                                .tint(NovaStyle.cyan)
                        }
                        ReadOnlyReport(title: "NOVA 통합 보고서", text: record.summary)
                        ShareLink(item: WorkflowExporter.markdown(record)) {
                            Label("전체 미션 기록 Markdown으로 공유", systemImage: "doc.text")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.bordered).tint(NovaStyle.cyan)
                        if let review = record.review { ReadOnlyReport(title: "QA 교차 검토", text: review) }
                        if let revision = record.revision { ReadOnlyReport(title: "수정 초안", text: revision) }
                    }
                    }
                } else { ErrorBanner(text: "삭제되었거나 찾을 수 없는 팀입니다.") }
            }.padding(18)
        }.navigationTitle("협업 실행").novaScreen()
    }
    private func start(_ team: AgentTeam) {
        guard !busy else { return }
        busy = true; errorText = nil; record = nil; progress = nil
        let mission = goal
        let options = WorkflowOptions(reviewPass: reviewPass, fallbackToAvailableModel: allowFallback,
            revisionPass: reviewPass && revisionPass, acceptanceCriteria: criteria, outputFormat: outputFormat)
        runTask = Task { @MainActor in
            do {
                let result = try await WorkflowEngine().run(team: team, goal: mission, options: options) { update in
                    progress = update
                }
                try Task.checkCancellation()
                record = result
                store.saveWorkflow(result)
            } catch is CancellationError {
                errorText = "작업을 중단했어요. 완료되지 않은 실행 결과는 저장하지 않았습니다."
            } catch {
                errorText = error.localizedDescription
            }
            busy = false
            runTask = nil
        }
    }
}

/// Stage-by-stage replay works both during a run and in the Memory Vault.
struct WorkflowTimelineView: View {
    let trace: [WorkflowTrace]
    @State private var expanded: Set<UUID> = []
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(title: "작업 타임라인", subtitle: "완료된 단계와 AI별 결과를 확인하세요")
            if trace.isEmpty {
                GlassPanel { Text("첫 번째 AI 작업이 완료되면 여기에 표시됩니다.")
                    .font(.caption).foregroundStyle(NovaStyle.muted) }
            }
            ForEach(Array(trace.enumerated()), id: \.element.id) { offset, event in
                GlassPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            if expanded.contains(event.id) { expanded.remove(event.id) }
                            else { expanded.insert(event.id) }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(offset + 1). \(event.stage)").font(.subheadline.bold())
                                    Text("\(event.model) · \(String(format: "%.1f", event.seconds))초\(event.demo ? " · DEMO" : "")")
                                        .font(.caption).foregroundStyle(NovaStyle.muted)
                                }
                                Spacer()
                                Image(systemName: expanded.contains(event.id) ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(NovaStyle.muted)
                            }
                        }.buttonStyle(.plain)
                        if expanded.contains(event.id) {
                            NovaFormattedResponse(text: event.output, compact: true)
                            ShareLink(item: event.output) { Label("결과 공유", systemImage: "square.and.arrow.up") }
                                .font(.caption).tint(NovaStyle.cyan)
                        } else {
                            Text(event.output).font(.caption).lineLimit(2)
                                .foregroundStyle(NovaStyle.muted)
                        }
                    }
                }
            }
        }
    }
}
