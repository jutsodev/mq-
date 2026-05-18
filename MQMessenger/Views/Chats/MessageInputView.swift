import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MessageInputView: View {
    @ObservedObject var vm: ChatRoomViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isInputFocused: Bool
    @State private var showMediaPicker = false
    @State private var showDocumentPicker = false
    @State private var showAttachMenu = false
    @State private var showFormatBar = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            if vm.replyingTo != nil || vm.editingMessage != nil {
                replyBar
            }

            if showFormatBar {
                formatToolbar
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: { showAttachMenu = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(themeManager.accentColor)
                }
                .confirmationDialog("attach".localized, isPresented: $showAttachMenu) {
                    Button("photo".localized) { showMediaPicker = true }
                    Button("file".localized) { showDocumentPicker = true }
                    Button("cancel".localized, role: .cancel) {}
                }

                HStack(alignment: .bottom, spacing: 4) {
                    TextField("message_placeholder".localized, text: $vm.messageText, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(1...20)
                        .focused($isInputFocused)
                        .onChange(of: vm.messageText) { _, _ in
                            vm.handleTyping()
                        }

                    Button(action: { showFormatBar.toggle() }) {
                        Image(systemName: "textformat")
                            .font(.system(size: 18))
                            .foregroundColor(showFormatBar ? themeManager.accentColor : .secondary)
                    }

                    Button(action: { vm.showEmojiPicker.toggle() }) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    }
                )

                Button(action: {
                    Task { await vm.sendMessage() }
                }) {
                    Image(systemName: vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .disabled(vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.replyingTo == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .photosPicker(isPresented: $showMediaPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            handlePhotoSelection(newItem)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in
                for url in urls {
                    handleFileSelection(url)
                }
            }
        }
    }

    private var formatToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                formatButton("bold", tag: "b")
                formatButton("italic", tag: "i")
                formatButton("underline", tag: "u")
                formatButton("strikethrough", tag: "s")
                formatButton("chevron.left.forwardslash.chevron.right", tag: "code")

                Divider().frame(height: 20)

                Button(action: { vm.messageFormat = vm.messageFormat == "html" ? "plain" : "html" }) {
                    Text("HTML")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(vm.messageFormat == "html" ? .white : themeManager.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(vm.messageFormat == "html" ? themeManager.accentColor : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.accentColor, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
    }

    private func formatButton(_ icon: String, tag: String) -> some View {
        Button(action: { wrapSelection(tag: tag) }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.accentColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(Color(.systemGray6))
                )
        }
    }

    private func wrapSelection(tag: String) {
        let text = vm.messageText
        if !text.isEmpty {
            vm.messageText = "<\(tag)>\(text)</\(tag)>"
            vm.messageFormat = "html"
        }
    }

    private var replyBar: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(themeManager.accentColor)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                if let reply = vm.replyingTo {
                    Text(reply.senderName ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.accentColor)
                    Text(reply.content ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let edit = vm.editingMessage {
                    Text("edit".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(edit.content ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: { vm.cancelReplyOrEdit() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            do {
                let response = try await APIService.shared.uploadFile(
                    data: data, filename: "photo.jpg", mimeType: "image/jpeg")
                await vm.sendMedia(url: response.url, type: "image", mediaType: "image/jpeg")
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        }
    }

    private func handleFileSelection(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        Task {
            do {
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                let response = try await APIService.shared.uploadFile(
                    data: data, filename: filename, mimeType: mimeType)
                await vm.sendMedia(url: response.url, type: "file", mediaType: mimeType)
            } catch {
                vm.errorMessage = error.localizedDescription
            }
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
