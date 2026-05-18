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

            if showAttachMenu {
                attachmentMenu
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            inputBar
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showAttachMenu)
        .animation(.easeInOut(duration: 0.2), value: showFormatBar)
        .photosPicker(isPresented: $showMediaPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            handlePhotoSelection(newItem)
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in
                for url in urls { handleFileSelection(url) }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button(action: {
                withAnimation { showAttachMenu.toggle() }
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: showAttachMenu
                                    ? [themeManager.accentColor, themeManager.accentColor.opacity(0.7)]
                                    : [Color(.systemGray5), Color(.systemGray4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)

                    Image(systemName: showAttachMenu ? "xmark" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(showAttachMenu ? .white : .primary)
                        .rotationEffect(.degrees(showAttachMenu ? 90 : 0))
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                TextField("message_placeholder".localized, text: $vm.messageText, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...20)
                    .focused($isInputFocused)
                    .onChange(of: vm.messageText) { _, _ in
                        vm.handleTyping()
                    }

                Button(action: { showFormatBar.toggle() }) {
                    Image(systemName: "textformat")
                        .font(.system(size: 16))
                        .foregroundColor(showFormatBar ? themeManager.accentColor : Color(.systemGray2))
                }

                Button(action: { vm.showEmojiPicker.toggle() }) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20))
                        .foregroundColor(Color(.systemGray2))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassInputField()

            Button(action: {
                Task { await vm.sendMessage() }
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                        .shadow(color: themeManager.accentColor.opacity(0.3), radius: 6, y: 3)

                    Image(systemName: vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "mic.fill" : "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.replyingTo == nil)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassInputBar()
    }

    private var attachmentMenu: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                attachItem(icon: "camera.fill", label: "camera".localized, color: .red) {
                    showAttachMenu = false
                }
                attachItem(icon: "photo.fill", label: "photo".localized, color: .purple) {
                    showAttachMenu = false
                    showMediaPicker = true
                }
                attachItem(icon: "doc.fill", label: "file".localized, color: .blue) {
                    showAttachMenu = false
                    showDocumentPicker = true
                }
                attachItem(icon: "location.fill", label: "location".localized, color: .green) {
                    showAttachMenu = false
                }
            }

            HStack(spacing: 20) {
                attachItem(icon: "person.crop.circle.fill", label: "contact".localized, color: .orange) {
                    showAttachMenu = false
                }
                attachItem(icon: "music.note", label: "audio".localized, color: .pink) {
                    showAttachMenu = false
                }
                attachItem(icon: "chart.bar.fill", label: "poll".localized, color: .teal) {
                    showAttachMenu = false
                }

                VStack(spacing: 6) {
                    Color.clear.frame(width: 52, height: 52)
                    Color.clear.frame(height: 14)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .opacity(0.95)

                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private func attachItem(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .attachMenuItem(color: color)

                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }
        }
    }

    private var formatToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                formatButton("bold", tag: "b")
                formatButton("italic", tag: "i")
                formatButton("underline", tag: "u")
                formatButton("strikethrough", tag: "s")
                formatButton("chevron.left.forwardslash.chevron.right", tag: "code")

                Divider().frame(height: 20)

                Button(action: { vm.messageFormat = vm.messageFormat == "html" ? "plain" : "html" }) {
                    Text("HTML")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(vm.messageFormat == "html" ? .white : themeManager.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(vm.messageFormat == "html" ? themeManager.accentColor : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(themeManager.accentColor, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .glassInputBar()
    }

    private func formatButton(_ icon: String, tag: String) -> some View {
        Button(action: { wrapSelection(tag: tag) }) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(themeManager.accentColor)
                .frame(width: 30, height: 30)
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
        .glassInputBar()
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
