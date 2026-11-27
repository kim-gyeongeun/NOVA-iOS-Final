import SwiftUI
import PhotosUI
import PDFKit
import UIKit

struct AIHubView: View {
    @EnvironmentObject private var store: NovaStore
    @Binding var requestedProvider: AIProvider?
    @State private var selectedRoom: UUID?
    @State private var roomToDelete: ChatRoom?
    @AppStorage("demoMode") private var demoMode = true
    @State private var serverReachable = false
    @State private var configuredProviders: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("새 대화")
                        .font(.system(.title2, design: .default, weight: .bold))
                    Text("원하는 AI 모델을 선택하세요.")
                        .font(.subheadline)
                        .foregroundStyle(NovaStyle.muted)
                }
                HStack {
                    NovaStatusChip(title: demoMode ? "데모 모드" : (serverReachable ? "서버 연결됨" : "서버 연결 확인 필요"), isDemo: demoMode || !serverReachable)
                    Spacer()
                    if !demoMode {
                        NavigationLink(destination: ConnectionCenterView()) {
                            Label("연결 관리", systemImage: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
                VStack(spacing: 0) {
                    ForEach(AIProvider.allCases) { provider in
                        Button { openRoom(with: provider) } label: {
                            HStack(spacing: 14) {
                                NovaFeatureIcon(symbol: provider.symbol, size: 48)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(provider.title)
                                        .font(.headline)
                                        .foregroundStyle(NovaStyle.ink)
                                    Text(provider.tagline)
                                        .font(.footnote)
                                        .foregroundStyle(NovaStyle.muted)
                                    if !demoMode && serverReachable {
                                        Text(configuredProviders.contains(provider.rawValue) ? "키 등록됨" : "키 등록 필요")
                                            .font(.caption)
                                            .foregroundStyle(configuredProviders.contains(provider.rawValue) ? NovaStyle.success : Color.orange)
                                    }
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(NovaStyle.accent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("선택한 AI로 새 채팅을 시작합니다")
                        if provider != AIProvider.allCases.last { Divider().padding(.leading, 78) }
                    }
                }
                .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(NovaStyle.stroke, lineWidth: 1))

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        SectionCaption(title: "최근 대화", subtitle: "이전 작업을 이어서 진행하세요")
                        Spacer()
                        Text("\(store.data.rooms.count)개")
                            .font(.footnote)
                            .foregroundStyle(NovaStyle.muted)
                    }
                    if store.data.rooms.isEmpty {
                        GlassPanel {
                            HStack(spacing: 13) {
                                NovaFeatureIcon(symbol: "bubble.left", tint: NovaStyle.muted)
                                Text("새 대화를 시작하면 여기에 저장됩니다.")
                                    .font(.subheadline)
                                    .foregroundStyle(NovaStyle.muted)
                            }
                        }
                    }
                    ForEach(store.data.rooms.sorted { $0.updatedAt > $1.updatedAt }) { room in
                        HStack(spacing: 0) {
                            NavigationLink(destination: ChatRoomView(roomID: room.id)) {
                                HStack(spacing: 12) {
                                    NovaFeatureIcon(symbol: room.provider.symbol, size: 40)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(room.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(NovaStyle.ink)
                                            .lineLimit(1)
                                        Text("\(room.provider.title) · \(room.turns.count)개 메시지")
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
                            .contextMenu {
                                Button(role: .destructive) { roomToDelete = room } label: {
                                    Label("대화 삭제", systemImage: "trash")
                                }
                            }
                            Menu {
                                Button(role: .destructive) { roomToDelete = room } label: {
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
                        .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NovaStyle.stroke, lineWidth: 1))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("채팅")
        .novaScreen()
        .onAppear { openRequestedProviderIfNeeded() }
        .onChange(of: requestedProvider) { _ in openRequestedProviderIfNeeded() }
        .task(id: demoMode) { await refreshConnections() }
        .confirmationDialog("이 대화를 삭제할까요?", isPresented: Binding(
            get: { roomToDelete != nil },
            set: { if !$0 { roomToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if let room = roomToDelete { store.deleteRoom(room.id) }
                roomToDelete = nil
            }
            Button("취소", role: .cancel) { roomToDelete = nil }
        } message: { Text("삭제한 대화는 복원할 수 없습니다.") }
        .navigationDestination(isPresented: Binding(
            get: { selectedRoom != nil },
            set: { if !$0 { selectedRoom = nil } }
        )) {
            if let id = selectedRoom { ChatRoomView(roomID: id) }
        }
    }

    @MainActor private func refreshConnections() async {
        guard !demoMode else {
            serverReachable = false
            configuredProviders = []
            return
        }
        do {
            let entries = try await AIService().connections()
            serverReachable = true
            configuredProviders = Set(entries.filter { $0.configured }.map { $0.id })
        } catch {
            serverReachable = false
            configuredProviders = []
        }
    }

    private func openRoom(with provider: AIProvider) {
        selectedRoom = store.addRoom(provider)
    }

    private func openRequestedProviderIfNeeded() {
        guard let provider = requestedProvider else { return }
        requestedProvider = nil
        openRoom(with: provider)
    }
}

struct ChatRoomView: View {
    @EnvironmentObject private var store: NovaStore
    let roomID: UUID
    @AppStorage("demoMode") private var demoMode = true
    @State private var input = ""
    @State private var sending = false
    @State private var errorText: String?
    @State private var photo: PhotosPickerItem?
    @State private var selectedImage: Data?
    @State private var pdfText: String?
    @State private var pdfLabel: String?
    @State private var pdfProcessing = false
    @State private var showFiles = false
    @State private var showVoice = false

    private var room: ChatRoom? { store.data.rooms.first { $0.id == roomID } }
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if let room, room.turns.isEmpty {
                            VStack(spacing: 13) {
                                NovaFeatureIcon(symbol: room.provider.symbol, size: 64)
                                Text("\(room.provider.title)와 이야기해 보세요").font(.headline)
                                Text("이미지·PDF를 추가하거나 음성으로 질문할 수도 있어요.").font(.footnote).foregroundStyle(NovaStyle.muted)
                                if demoMode { Text("데모 모드에서는 예시 답변을 표시해요.")
                                    .font(.footnote).foregroundStyle(NovaStyle.muted) }
                            }.frame(maxWidth: .infinity).padding(.top, 65)
                        }
                        ForEach(room?.turns ?? []) { turn in
                            HStack(alignment: .top, spacing: 0) {
                                if turn.role == "user" { Spacer(minLength: 35) }
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 8) {
                                        Text(turn.role == "user" ? "나" : (room?.provider.title ?? "AI"))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(turn.role == "user" ? Color.white.opacity(0.75) : NovaStyle.muted)
                                        Spacer(minLength: 0)
                                        Button {
                                            UIPasteboard.general.string = turn.text
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                                .font(.footnote)
                                                .foregroundStyle(turn.role == "user" ? Color.white.opacity(0.85) : NovaStyle.muted)
                                                .frame(width: 38, height: 38)
                                        }
                                        .accessibilityLabel("메시지 복사")
                                        if turn.role != "user" {
                                            ShareLink(item: turn.text) {
                                                Image(systemName: "square.and.arrow.up")
                                                    .font(.footnote)
                                                    .foregroundStyle(NovaStyle.muted)
                                                    .frame(width: 38, height: 38)
                                            }
                                            .accessibilityLabel("답변 공유")
                                        }
                                    }
                                    if turn.role == "user" {
                                        Text(turn.text)
                                            .font(.body)
                                            .foregroundStyle(.white)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .textSelection(.enabled)
                                    } else {
                                        NovaFormattedResponse(text: turn.text)
                                            .foregroundStyle(NovaStyle.ink)
                                    }
                                    if let note = turn.attachmentNote {
                                        Label(note, systemImage: "paperclip")
                                            .font(.caption)
                                            .foregroundStyle(NovaStyle.muted)
                                    }
                                }
                                .padding(15)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(turn.role == "user" ? NovaStyle.deep : NovaStyle.panel,
                                            in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 17).stroke(turn.role == "user" ? Color.clear : NovaStyle.stroke, lineWidth: 1))
                                if turn.role != "user" { Spacer(minLength: 17) }
                            }
                            .id(turn.id)
                        }
                        if sending { HStack { ProgressView(); Text("응답 생성 중...").font(.caption) }.foregroundStyle(NovaStyle.muted) }
                        if let errorText { ErrorBanner(text: errorText) }
                    }.padding(16)
                }.onChange(of: room?.turns.count) { _ in
                    if let id = room?.turns.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                if pdfProcessing {
                    HStack(spacing: 8) { ProgressView(); Text("PDF 읽는 중...").font(.footnote) }
                        .foregroundStyle(NovaStyle.muted)
                }
                if selectedImage != nil || pdfText != nil {
                    HStack(spacing: 9) {
                        Label(selectedImage != nil ? "사진이 첨부됐어요" : (pdfLabel ?? "PDF가 첨부됐어요"),
                              systemImage: selectedImage != nil ? "photo" : "doc.richtext")
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            selectedImage = nil; photo = nil; pdfText = nil; pdfLabel = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(width: 32, height: 32)
                        }
                        .accessibilityLabel("첨부 취소")
                    }
                    .foregroundStyle(NovaStyle.accent)
                }
                HStack(alignment: .center, spacing: 9) {
                    PhotosPicker(selection: $photo, matching: .images) {
                        Image(systemName: "photo")
                            .font(.system(size: 17))
                            .frame(width: 29, height: 44)
                    }
                    .accessibilityLabel("사진 첨부")
                    Button { showFiles = true } label: {
                        Image(systemName: "doc")
                            .font(.system(size: 17))
                            .frame(width: 29, height: 44)
                    }
                    .accessibilityLabel("PDF 첨부")
                    Button { showVoice = true } label: {
                        Image(systemName: "mic")
                            .font(.system(size: 17))
                            .frame(width: 29, height: 44)
                    }
                    .accessibilityLabel("음성으로 입력")
                    NovaChatSingleLineInput(placeholder: "메시지 입력", text: $input)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .padding(.horizontal, 12)
                        .background(NovaStyle.bg, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NovaStyle.stroke, lineWidth: 1))
                    Button { Task { await send() } } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(NovaStyle.accent, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .accessibilityLabel("메시지 전송")
                    .disabled(sending || pdfProcessing ||
                              (input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil && pdfText == nil))
                    .opacity(sending || pdfProcessing ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .foregroundStyle(NovaStyle.accent)
                if demoMode {
                    Text("데모 응답")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(NovaStyle.panel)
            .overlay(alignment: .top) { NovaStyle.stroke.frame(height: 1) }
        }
        .navigationTitle(room?.provider.title ?? "채팅")
        .navigationBarTitleDisplayMode(.inline)
        .novaScreen()
        .onChange(of: photo) { item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    // Downsize before network upload; aim to remain under backend's 5 MB limit.
                    let limit: CGFloat = 1600
                    let ratio = min(1, limit / max(image.size.width, image.size.height))
                    let resized: UIImage
                    if ratio < 1 {
                        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                        let renderer = UIGraphicsImageRenderer(size: newSize)
                        resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
                    } else { resized = image }
                    selectedImage = resized.jpegData(compressionQuality: 0.65)
                }
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { result in
            do {
                let url = try result.get()
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                pdfProcessing = true
                Task { @MainActor in
                    defer { pdfProcessing = false }
                    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
                    do {
                        try data.write(to: temp, options: .atomic)
                        defer { try? FileManager.default.removeItem(at: temp) }
                        let pageTexts = try await DocumentReader.pagesFromPDF(temp)
                        let recognized = DocumentReader.makeEvidence(pageTexts)
                        guard !recognized.isEmpty else { throw NovaError.server("PDF에서 글자를 찾지 못했어요.") }
                        pdfText = recognized
                        pdfLabel = filename
                    } catch { errorText = "PDF 읽기 실패: \(error.localizedDescription)" }
                }
            } catch { errorText = error.localizedDescription }
        }
        .sheet(isPresented: $showVoice) { VoiceInputSheet { text in input = text } }
    }
    private func send() async {
        guard var room, !pdfProcessing else { return }
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let question = prompt.isEmpty ? "첨부 파일을 분석해서 설명해줘." : prompt
        let fileContent = pdfText.map { "\n\n[PDF 추출 텍스트]\n\($0)" } ?? ""
        let image = selectedImage?.base64EncodedString()
        let note = image != nil ? "이미지" : pdfLabel
        let history = room.turns
        room.turns.append(ChatTurn(role: "user", text: question, attachmentNote: note))
        if history.isEmpty { room.title = String(question.prefix(35)) }
        room.updatedAt = Date(); store.updateRoom(room)
        input = ""; selectedImage = nil; photo = nil; pdfText = nil; pdfLabel = nil; errorText = nil; sending = true
        defer { sending = false }
        do {
            let answer = try await AIService().ask(room.provider, message: question + fileContent, history: history, imageBase64: image)
            guard var updated = store.data.rooms.first(where: { $0.id == roomID }) else { return }
            updated.turns.append(ChatTurn(role: "assistant", text: answer))
            updated.updatedAt = Date(); store.updateRoom(updated)
        } catch { errorText = error.localizedDescription }
    }
}
