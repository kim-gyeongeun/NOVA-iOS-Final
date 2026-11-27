import SwiftUI
import UIKit

// NOVA 11 design system: calm surfaces, clear hierarchy and accessible tap targets.
// No external images, custom font downloads or excessive decorative gradients.
enum NovaStyle {
    static let bg = Color(red: 0.977, green: 0.982, blue: 0.990)
    static let panel = Color.white
    static let elevated = Color(red: 0.936, green: 0.949, blue: 0.974)
    static let stroke = Color(red: 0.85, green: 0.88, blue: 0.92).opacity(0.75)
    static let purple = Color(red: 0.15, green: 0.31, blue: 0.70) // retained name for old screens
    static let cyan = Color(red: 0.15, green: 0.33, blue: 0.70)
    static let muted = Color(red: 0.39, green: 0.44, blue: 0.53)
    static let accent = Color(red: 0.14, green: 0.32, blue: 0.72)
    static let ink = Color(red: 0.085, green: 0.13, blue: 0.21)
    static let deep = Color(red: 0.08, green: 0.15, blue: 0.27)
    static let success = Color(red: 0.11, green: 0.48, blue: 0.37)
    // Retained for source compatibility; intentionally a quiet solid color.
    static let gradient = LinearGradient(colors: [purple, purple], startPoint: .leading, endPoint: .trailing)
}

struct NovaBackground: View {
    var body: some View { NovaStyle.bg.ignoresSafeArea() }
}

struct GlassPanel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NovaStyle.panel, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(NovaStyle.stroke, lineWidth: 1))
    }
}

struct PrimaryAction: View {
    let title: String
    let icon: String
    let busy: Bool
    let action: () -> Void
    init(_ title: String, icon: String = "arrow.right", busy: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.busy = busy; self.action = action
    }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if busy { ProgressView().tint(NovaStyle.bg) }
                else { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(NovaStyle.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.68 : 1)
    }
}

struct SectionCaption: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(.title3, design: .default, weight: .semibold)).foregroundStyle(NovaStyle.ink)
            if !subtitle.isEmpty { Text(subtitle).font(.footnote).foregroundStyle(NovaStyle.muted) }
        }
    }
}

struct ProviderPill: View {
    let provider: AIProvider
    var body: some View {
        Label(provider.title, systemImage: provider.symbol)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 11).padding(.vertical, 8)
            .background(NovaStyle.elevated, in: Capsule())
            .overlay(Capsule().stroke(NovaStyle.stroke, lineWidth: 1))
    }
}

struct ProviderRow: View {
    let provider: AIProvider
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: provider.symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(NovaStyle.accent)
                .frame(width: 43, height: 43)
                .background(NovaStyle.elevated, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.title).font(.subheadline.weight(.semibold))
                Text(provider.tagline).font(.caption).foregroundStyle(NovaStyle.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(NovaStyle.muted)
        }
    }
}

struct TagChip: View {
    let title: String
    let icon: String
    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(NovaStyle.elevated, in: Capsule())
    }
}

struct ErrorBanner: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.footnote).foregroundStyle(.orange)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ReadOnlyReport: View {
    let title: String
    let text: String
    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(NovaStyle.accent)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("결과 복사")
                    ShareLink(item: text) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(NovaStyle.accent)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("결과 공유")
                }
                NovaFormattedResponse(text: text)
            }
        }
    }
}

extension View {
    func novaScreen() -> some View {
        background(NovaBackground())
            .foregroundStyle(NovaStyle.ink)
            .tint(NovaStyle.accent)
    }
}

// Render headings, inline emphasis and code fragments from model responses.
// If a model emits malformed Markdown, retain its complete text instead of failing.
enum NovaMarkdown {
    static func attributed(_ source: String) -> AttributedString {
        (try? AttributedString(markdown: source,
                               options: .init(interpretedSyntax: .full)))
        ?? AttributedString(source)
    }
}



// NOVA 12.3: Markdown block renderer shared by chat, debate, comparison,
// agent traces, reports and the saved vault. AttributedString by itself
// cannot render paragraph/list block layout reliably in SwiftUI Text.
private struct NovaResponseBlock: Identifiable {
    enum Kind {
        case paragraph, heading(Int), bullet, numbered, quote, code, divider
    }
    let id: Int
    let kind: Kind
    let text: String
    let marker: String
}

extension NovaMarkdown {
    static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text,
              options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
        ?? AttributedString(text)
    }

    fileprivate static func blocks(_ response: String) -> [NovaResponseBlock] {
        // Preserve the model's raw newlines. The previous single AttributedString
        // converted block Markdown to inline text and lost paragraph structure.
        let normalized = response
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var result: [NovaResponseBlock] = []
        var paragraph: [String] = []
        var code: [String] = []
        var inCode = false
        func append(_ kind: NovaResponseBlock.Kind, _ body: String, _ marker: String = "") {
            result.append(NovaResponseBlock(id: result.count, kind: kind, text: body, marker: marker))
        }
        func flushParagraph() {
            if !paragraph.isEmpty {
                append(.paragraph, paragraph.joined(separator: "\n"))
                paragraph.removeAll()
            }
        }
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if inCode { append(.code, code.joined(separator: "\n")); code.removeAll() }
                else { flushParagraph() }
                inCode.toggle()
                continue
            }
            if inCode { code.append(raw); continue }
            if line.isEmpty { flushParagraph(); continue }
            if line == "---" || line == "***" || line == "___" {
                flushParagraph(); append(.divider, ""); continue
            }
            let hashes = line.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes) {
                let suffix = line.dropFirst(hashes)
                if suffix.first == " " {
                    flushParagraph()
                    append(.heading(hashes), String(suffix).trimmingCharacters(in: .whitespaces))
                    continue
                }
            }
            if line.hasPrefix("> ") {
                flushParagraph(); append(.quote, String(line.dropFirst(2))); continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flushParagraph(); append(.bullet, String(line.dropFirst(2)), "•"); continue
            }
            if let range = line.range(of: #"^\d{1,3}[.)]\s+"#, options: .regularExpression) {
                flushParagraph()
                let mark = String(line[range]).trimmingCharacters(in: .whitespaces)
                append(.numbered, String(line[range.upperBound...]), mark)
                continue
            }
            // Entire bold lines are often intended as section titles.
            if line.hasPrefix("**"), line.hasSuffix("**"), line.count > 4,
               !line.dropFirst(2).dropLast(2).contains("**") {
                flushParagraph(); append(.heading(3), String(line.dropFirst(2).dropLast(2)))
                continue
            }
            paragraph.append(raw.trimmingCharacters(in: .whitespaces))
        }
        if inCode { append(.code, code.joined(separator: "\n")) }
        flushParagraph()
        return result
    }
}

struct NovaFormattedResponse: View {
    let text: String
    var compact: Bool = false

    private var parsed: [NovaResponseBlock] { NovaMarkdown.blocks(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 12) {
            ForEach(parsed) { block in
                switch block.kind {
                case .paragraph:
                    Text(NovaMarkdown.inline(block.text))
                        .font(compact ? .subheadline : .body)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                case .heading(let level):
                    Text(NovaMarkdown.inline(block.text))
                        .font(level <= 2 ? .title3.weight(.semibold) : .headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, compact ? 2 : 4)
                        .textSelection(.enabled)
                case .bullet, .numbered:
                    HStack(alignment: .top, spacing: 10) {
                        Text(block.marker).font(.subheadline.weight(.semibold))
                            .foregroundStyle(NovaStyle.accent)
                            .frame(minWidth: 17, alignment: .trailing)
                        Text(NovaMarkdown.inline(block.text))
                            .font(compact ? .subheadline : .body)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }
                case .quote:
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(NovaStyle.accent.opacity(0.45))
                            .frame(width: 3)
                        Text(NovaMarkdown.inline(block.text))
                            .font(.subheadline)
                            .foregroundStyle(NovaStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                case .code:
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(block.text)
                            .font(.system(size: 13, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NovaStyle.elevated, in: RoundedRectangle(cornerRadius: 10))
                case .divider:
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Compact one-line chat input. A native UITextField also preserves the
// system's Korean marked-text composition without reassigning while focused.
struct NovaChatSingleLineInput: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.placeholder = placeholder
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = UIColor.label
        field.tintColor = UIColor(red: 0.14, green: 0.32, blue: 0.72, alpha: 1)
        field.returnKeyType = .done
        field.clearButtonMode = .never
        field.text = text
        field.accessibilityLabel = placeholder
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = isEnabled
        if !field.isFirstResponder && field.markedTextRange == nil && field.text != text {
            field.text = text
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NovaChatSingleLineInput
        init(_ parent: NovaChatSingleLineInput) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            if parent.text != field.text { parent.text = field.text ?? "" }
        }
        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
        func textFieldDidEndEditing(_ field: UITextField) {
            if parent.text != field.text { parent.text = field.text ?? "" }
        }
    }
}

// Reusable quiet product surfaces: no ornamental gradients or dense tiny labels.
struct NovaFeatureIcon: View {
    let symbol: String
    var tint: Color = NovaStyle.accent
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.075), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct NovaStatusChip: View {
    let title: String
    let isDemo: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(isDemo ? Color.orange : NovaStyle.success).frame(width: 6, height: 6)
            Text(title).font(.caption.weight(.medium))
        }
        .foregroundStyle(NovaStyle.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(NovaStyle.panel, in: Capsule())
        .overlay(Capsule().stroke(NovaStyle.stroke, lineWidth: 1))
    }
}


// Korean IME-safe text editor used by NOVA input fields.
// UITextView owns the in-progress marked text. We publish the SwiftUI binding
// only once the IME has committed composition; SwiftUI must not overwrite
// marked text while Hangul syllables are being assembled.
struct HangulTextInput: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var monospaced: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    init(_ placeholder: String, text: Binding<String>, monospaced: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.monospaced = monospaced
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = UIColor.label
        view.tintColor = UIColor(red: 0.14, green: 0.32, blue: 0.72, alpha: 1)
        view.font = monospaced ? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular) : UIFont.preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = !monospaced
        view.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = true
        view.keyboardDismissMode = .interactive
        view.autocorrectionType = .default
        view.text = text
        view.accessibilityLabel = placeholder

        let label = UILabel()
        label.text = placeholder
        label.font = view.font
        label.textColor = .placeholderText
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -8)
        ])
        context.coordinator.placeholderLabel = label
        label.isHidden = !text.isEmpty
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        view.isEditable = isEnabled
        view.isSelectable = true
        // Overwriting `text` while markedTextRange exists breaks Korean IME.
        if !view.isFirstResponder && view.markedTextRange == nil && view.text != text {
            view.text = text
        }
        context.coordinator.placeholderLabel?.isHidden = !view.text.isEmpty
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: HangulTextInput
        weak var placeholderLabel: UILabel?
        init(_ parent: HangulTextInput) { self.parent = parent }

        func textViewDidChange(_ view: UITextView) {
            placeholderLabel?.isHidden = !view.text.isEmpty
            // The UIKit editor owns marked text. Binding updates are safe because
            // updateUIView never rewrites the active editing session.
            if parent.text != view.text { parent.text = view.text }
        }

        func textViewDidEndEditing(_ view: UITextView) {
            // Commit even if focus moved while composing the final syllable.
            if parent.text != view.text { parent.text = view.text }
            placeholderLabel?.isHidden = !view.text.isEmpty
        }
    }
}
