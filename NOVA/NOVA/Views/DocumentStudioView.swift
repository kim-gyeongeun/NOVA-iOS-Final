import SwiftUI
import PhotosUI
import PDFKit
import AVFoundation
import UIKit
import UniformTypeIdentifiers

private enum AnalysisPreset: String, CaseIterable, Identifiable {
    case summary = "핵심 요약"
    case tasks = "일정·할 일"
    case review = "문제점 검토"
    case questions = "질문·학습"
    var id: String { rawValue }
    var instruction: String {
        switch self {
        case .summary: return "원문을 왜곡하지 않고 핵심 내용, 주요 항목, 기억할 사항을 구분해서 요약하세요."
        case .tasks: return "마감일, 시간, 장소, 담당자, 해야 할 일을 추출하세요. 원문에 날짜가 없으면 추측하지 말고 미기재라고 쓰세요."
        case .review: return "상충된 설명, 빠진 조건, 모호한 문장과 확인이 필요한 위험을 찾아주세요. 확인 불가능한 것은 단정하지 마세요."
        case .questions: return "자료를 바탕으로 핵심 개념 5개, 이해 확인 질문 5개 및 정답·근거를 생성하세요."
        }
    }
    var icon: String {
        switch self {
        case .summary: return "text.alignleft"
        case .tasks: return "calendar.badge.clock"
        case .review: return "checkmark.shield"
        case .questions: return "books.vertical"
        }
    }
}

struct DocumentStudioView: View {
    @EnvironmentObject private var store: NovaStore
    @State private var photo: PhotosPickerItem?
    @State private var cameraOpen = false
    @State private var fileOpen = false
    @State private var busyOCR = false
    @State private var busyAI = false
    @State private var pages: [PageText] = []
    @State private var sourceTitle = ""
    @State private var sourceType = ""
    @State private var preset: AnalysisPreset = .summary
    @State private var provider: AIProvider = .openai
    @State private var answer: String?
    @State private var errorText: String?
    @State private var extractedExpanded = false
    @State private var speech = AVSpeechSynthesizer()
    @State private var saved = false

    private var evidence: String { DocumentReader.makeEvidence(pages) }
    private var canAnalyze: Bool { !evidence.isEmpty && !busyOCR && !busyAI }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                SectionCaption(title: "문서 분석", subtitle: "사진과 PDF에서 내용을 추출하고 AI로 분석하세요")
                GlassPanel {
                    VStack(alignment: .leading, spacing: 13) {
                        Label("자료 가져오기", systemImage: "doc.viewfinder").font(.headline)
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $photo, matching: .images) {
                                Label("앨범", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered)
                            Button { cameraOpen = true } label: {
                                Label("촬영", systemImage: "camera").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered).disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                            Button { fileOpen = true } label: {
                                Label("PDF", systemImage: "doc.richtext").frame(maxWidth: .infinity)
                            }.buttonStyle(.bordered)
                        }
                        Text("OCR은 아이폰 안에서 처리해요. AI 분석을 누르기 전에는 텍스트가 서버로 전송되지 않습니다.")
                            .font(.caption).foregroundStyle(NovaStyle.muted)
                        if busyOCR { ProgressView("문서 인식 중...") }
                        if !pages.isEmpty {
                            Label("\(sourceTitle) · \(pages.count)페이지", systemImage: "checkmark.circle.fill")
                                .font(.subheadline).foregroundStyle(NovaStyle.cyan)
                            Text("OCR 문자 수: \(evidence.count)자").font(.caption).foregroundStyle(NovaStyle.muted)
                            Button("다른 문서 선택 시 현재 결과는 초기화됩니다.") { reset() }
                                .font(.caption).foregroundStyle(NovaStyle.muted)
                        }
                    }
                }
                if !pages.isEmpty {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 11) {
                            Button { extractedExpanded.toggle() } label: {
                                HStack {
                                    Label("인식된 텍스트 확인", systemImage: "text.viewfinder")
                                    Spacer()
                                    Image(systemName: extractedExpanded ? "chevron.up" : "chevron.down")
                                }
                            }.foregroundStyle(NovaStyle.ink)
                            if extractedExpanded {
                                Text(evidence.isEmpty ? "글자를 인식하지 못했어요. 다른 이미지로 시도해 주세요." : evidence)
                                    .font(.caption.monospaced()).textSelection(.enabled)
                            }
                        }
                    }
                    SectionCaption(title: "분석 방식", subtitle: "문서 내용에 맞게 AI에게 맡길 일을 선택하세요")
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                        ForEach(AnalysisPreset.allCases) { item in
                            Button { preset = item } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: item.icon)
                                    Text(item.rawValue).font(.subheadline.weight(.semibold))
                                }.frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(preset == item ? NovaStyle.purple.opacity(0.45) : NovaStyle.panel, in: RoundedRectangle(cornerRadius: 13))
                            }.buttonStyle(.plain)
                        }
                    }
                    GlassPanel {
                        Picker("분석할 AI", selection: $provider) {
                            ForEach(AIProvider.allCases) { model in Text(model.title).tag(model) }
                        }
                        Text("현재 모드: \(AIService().demo ? "DEMO · 예시 결과" : "LIVE · 실제 API 요청")")
                            .font(.caption).foregroundStyle(AIService().demo ? .orange : NovaStyle.cyan)
                    }
                    PrimaryAction("AI로 분석하기", icon: "sparkles", busy: busyAI) {
                        Task { await analyze() }
                    }.disabled(!canAnalyze)
                }
                if let errorText { ErrorBanner(text: errorText) }
                if let answer {
                    ReadOnlyReport(title: "AI 분석 결과", text: answer)
                    HStack(spacing: 13) {
                        ShareLink(item: exportedText(answer)) { Label("공유", systemImage: "square.and.arrow.up") }
                        Button { if speech.isSpeaking { speech.stopSpeaking(at: .immediate) } else {
                            let utterance = AVSpeechUtterance(string: String(answer.prefix(3000)))
                            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
                            speech.speak(utterance)
                        }} label: { Label("음성 읽기", systemImage: "speaker.wave.2") }
                    }.font(.subheadline)
                    if saved { Label("보관함에 저장됨", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(NovaStyle.cyan) }
                    Text("AI가 생성한 분석은 틀릴 수 있어요. [P번호-L번호] 출처를 원문과 대조하세요.")
                        .font(.caption).foregroundStyle(NovaStyle.muted)
                }
            }.padding(18)
        }
        .navigationTitle("문서 분석")
        .novaScreen()
        .onDisappear { speech.stopSpeaking(at: .immediate) }
        .onChange(of: photo) { item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                await loadImage(data, label: "앨범 사진")
            }
        }
        .sheet(isPresented: $cameraOpen) { CameraCapture { data in Task { await loadImage(data, label: "카메라 촬영") } } }
        .fileImporter(isPresented: $fileOpen, allowedContentTypes: [.pdf]) { result in
            do {
                let url = try result.get()
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                // Load bytes before losing security-scope access.
                let bytes = try Data(contentsOf: url)
                Task { await loadPDF(bytes, label: url.lastPathComponent) }
            } catch { errorText = error.localizedDescription }
        }
    }

    private func reset() {
        speech.stopSpeaking(at: .immediate)
        pages = []; answer = nil; sourceTitle = ""; sourceType = ""; saved = false
        errorText = nil; photo = nil
    }

    @MainActor private func loadImage(_ data: Data, label: String) async {
        reset(); busyOCR = true
        defer { busyOCR = false }
        do {
            let recognized = try await DocumentReader.extractText(from: data)
            guard !recognized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw NovaError.server("사진에서 글자를 찾지 못했어요.") }
            pages = [PageText(pageNumber: 1, text: String(recognized.prefix(12000)))]
            sourceTitle = label; sourceType = "image"
        } catch { errorText = "OCR 실패: \(error.localizedDescription)" }
    }

    @MainActor private func loadPDF(_ bytes: Data, label: String) async {
        reset(); busyOCR = true
        defer { busyOCR = false }
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
            try bytes.write(to: url, options: .atomic)
            defer { try? FileManager.default.removeItem(at: url) }
            let extracted = try await DocumentReader.pagesFromPDF(url)
            guard extracted.contains(where: { !$0.text.isEmpty }) else { throw NovaError.server("PDF에서 글자를 인식하지 못했어요.") }
            pages = extracted; sourceTitle = label; sourceType = "pdf"
        } catch { errorText = "PDF 분석 실패: \(error.localizedDescription)" }
    }

    @MainActor private func analyze() async {
        guard canAnalyze else { return }
        busyAI = true; answer = nil; errorText = nil; saved = false
        defer { busyAI = false }
        let mode = AIService().demo
        do {
            let guidance = "너는 문서 분석가야. 제공된 OCR 원문에 실제로 적힌 내용만 근거로 분석해. 문서에 없는 사실, 날짜, 페이지를 지어내지 마. 중요한 주장마다 [P1-L3]처럼 제공된 실제 행 번호를 표시해. 불명확하면 '확인 필요'로 표시해."
            let query = "작업: \(preset.instruction)\n\n[원문 OCR — 정확한 인식을 보장하지 않음]\n\(evidence)"
            let output = try await AIService().ask(provider, message: query, system: guidance)
            answer = output
            let record = DocumentInsight(title: sourceTitle, sourceType: sourceType,
                                         pages: pages, prompt: preset.rawValue,
                                         analysis: output, provider: provider, demo: mode)
            store.saveDocumentInsight(record)
            saved = true
        } catch { errorText = "AI 분석 실패: \(error.localizedDescription)" }
    }

    private func exportedText(_ output: String) -> String {
        DocumentInsight(title: sourceTitle, sourceType: sourceType, pages: pages,
                        prompt: preset.rawValue, analysis: output, provider: provider,
                        demo: AIService().demo).shareText
    }
}

// UIKit camera remains optional so the feature works on iPhone simulators as well.
private struct CameraCapture: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onPhoto: (Data) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPhoto: onPhoto, dismiss: dismiss) }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPhoto: (Data) -> Void
        let dismiss: DismissAction
        init(onPhoto: @escaping (Data) -> Void, dismiss: DismissAction) { self.onPhoto = onPhoto; self.dismiss = dismiss }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { dismiss() }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage,
               let jpeg = image.jpegData(compressionQuality: 0.8) { onPhoto(jpeg) }
            dismiss()
        }
    }
}
