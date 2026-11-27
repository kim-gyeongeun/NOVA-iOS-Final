import SwiftUI

// Product-first dashboard: primary action, two high-value paths, recents,
// with secondary experiments progressively disclosed under All Tools.
struct HomeView: View {
    @EnvironmentObject private var store: NovaStore
    @Binding var tab: Int
    @Binding var requestedProvider: AIProvider?
    @AppStorage("demoMode") private var demoMode = true
    @State private var roomToDelete: ChatRoom?

    private var recentRooms: [ChatRoom] {
        Array(store.data.rooms.sorted { $0.updatedAt > $1.updatedAt }.prefix(2))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                header
                hero
                quickActions
                recents
                modelShortcuts
                allTools
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 36)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .novaScreen()
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("이 대화를 삭제할까요?", isPresented: Binding(
            get: { roomToDelete != nil },
            set: { if !$0 { roomToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if let room = roomToDelete { store.deleteRoom(room.id) }
                roomToDelete = nil
            }
            Button("취소", role: .cancel) { roomToDelete = nil }
        } message: {
            Text("이 대화의 메시지가 영구적으로 삭제됩니다. 삭제 후 복원할 수 없습니다.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(NovaStyle.deep)
                Text("N")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 43, height: 43)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("NOVA").font(.system(size: 20, weight: .bold)).tracking(-0.7)
                Text("AI Workspace").font(.caption).foregroundStyle(NovaStyle.muted)
            }
            Spacer()
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(NovaStyle.ink)
                    .frame(width: 44, height: 44)
                    .background(NovaStyle.panel, in: Circle())
                    .overlay(Circle().stroke(NovaStyle.stroke, lineWidth: 1))
            }
            .accessibilityLabel("설정")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("NOVA WORKSPACE")
                    .font(.caption.weight(.semibold))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(demoMode ? Color.orange : Color.green).frame(width: 6, height: 6)
                    Text(demoMode ? "데모" : "실사용 설정")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("오늘은 무엇을\n해볼까요?")
                    .font(.system(size: 27, weight: .bold))
                    .tracking(-1.0)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.white)
                Text("대화부터 협업까지, 한곳에서.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Button { tab = 1 } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("새 대화 시작").fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline)
                .foregroundStyle(NovaStyle.deep)
                .padding(.horizontal, 17)
                .frame(height: 51)
                .background(.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("AI를 선택하고 새 채팅을 시작합니다")
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NovaStyle.deep, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionCaption(title: "바로 시작하기", subtitle: "가장 자주 쓰는 AI 기능")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                NavigationLink(destination: CompareView()) {
                    actionCard(symbol: "rectangle.split.3x1", title: "답변 비교", detail: "3개의 관점")
                }
                Button { tab = 2 } label: {
                    actionCard(symbol: "person.3", title: "AI 팀 협업", detail: "함께 해결하기")
                }
                NavigationLink(destination: DocumentStudioView()) {
                    actionCard(symbol: "doc.text.viewfinder", title: "문서 분석", detail: "사진 · PDF")
                }
                NavigationLink(destination: WorkbenchView()) {
                    actionCard(symbol: "doc.text", title: "보고서", detail: "편집 · 내보내기")
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func actionCard(symbol: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            NovaFeatureIcon(symbol: symbol)
            Spacer(minLength: 0)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NovaStyle.ink)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(NovaStyle.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(16)
        .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(NovaStyle.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var recents: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                SectionCaption(title: "최근 대화", subtitle: "이어서 작업하기")
                Spacer()
                Button("전체 보기") { tab = 3 }
                    .font(.footnote.weight(.semibold))
            }
            if recentRooms.isEmpty {
                HStack(spacing: 12) {
                    NovaFeatureIcon(symbol: "bubble.left", tint: NovaStyle.muted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("첫 대화를 시작해 보세요").font(.subheadline.weight(.semibold))
                        Text("대화가 여기에 표시됩니다").font(.footnote).foregroundStyle(NovaStyle.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 17))
            } else {
                VStack(spacing: 0) {
                    ForEach(recentRooms) { room in
                        HStack(spacing: 0) {
                            NavigationLink(destination: ChatRoomView(roomID: room.id)) {
                                HStack(spacing: 12) {
                                    NovaFeatureIcon(symbol: room.provider.symbol, size: 40)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(room.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(NovaStyle.ink)
                                            .lineLimit(1)
                                        Text(room.provider.title + " · 메시지 " + String(room.turns.count) + "개")
                                            .font(.footnote)
                                            .foregroundStyle(NovaStyle.muted)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.leading, 14)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Menu {
                                Button(role: .destructive) {
                                    roomToDelete = room
                                } label: {
                                    Label("대화 삭제", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(NovaStyle.muted)
                                    .frame(width: 48, height: 58)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel(room.title + " 대화 관리")
                        }
                        if room.id != recentRooms.last?.id {
                            Divider().padding(.leading, 65)
                        }
                    }
                }
                .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(NovaStyle.stroke, lineWidth: 1))
            }
        }
    }

    private var modelShortcuts: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionCaption(title: "AI 모델", subtitle: "원하는 모델로 바로 대화하세요")
            HStack(spacing: 8) {
                ForEach(AIProvider.allCases) { provider in
                    Button {
                        requestedProvider = provider
                        tab = 1
                    } label: {
                        VStack(spacing: 9) {
                            Image(systemName: provider.symbol)
                                .font(.system(size: 18, weight: .medium))
                                .frame(height: 24)
                            Text(provider.title)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(NovaStyle.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(NovaStyle.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(provider.title + "로 새 대화")
                }
            }
        }
    }

    private var allTools: some View {
        NavigationLink(destination: LabView()) {
            HStack(spacing: 11) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 18))
                    .foregroundStyle(NovaStyle.accent)
                Text("모든 AI 도구 보기")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NovaStyle.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote).foregroundStyle(NovaStyle.muted)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(NovaStyle.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
