import SwiftUI
import PhotosUI

struct MessageInputView: View {
    @ObservedObject var vm: ChatRoomViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isInputFocused: Bool
    @State private var showMediaPicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            if vm.replyingTo != nil || vm.editingMessage != nil {
                replyBar
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: { showMediaPicker = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(themeManager.accentColor)
                }

                HStack(alignment: .bottom, spacing: 4) {
                    TextField("message_placeholder".localized, text: $vm.messageText, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .onChange(of: vm.messageText) { _, _ in
                            vm.handleTyping()
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
}
