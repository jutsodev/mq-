import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @ObservedObject var vm: ProfileViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    avatarSection
                    formSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("edit_profile".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task {
                            await vm.saveProfile()
                            if vm.saveSuccess { dismiss() }
                        }
                    }) {
                        if vm.isSaving {
                            ProgressView()
                        } else {
                            Text("done".localized)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(vm.isSaving)
                }
            }
            .alert("error".localized, isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let imageData = vm.selectedImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        AvatarView(
                            name: vm.displayName.isEmpty ? "?" : vm.displayName,
                            avatarURL: vm.user?.avatarURL,
                            size: 100
                        )
                    }

                    Circle()
                        .fill(.black.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )
                        .opacity(0.7)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                handlePhotoSelection(newItem)
            }

            Text("change_avatar".localized)
                .font(.system(size: 14))
                .foregroundColor(themeManager.accentColor)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("display_name".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("display_name".localized, text: $vm.displayName)
                    .font(.system(size: 16))
                    .glassTextField()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("username".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    Text("@")
                        .foregroundColor(.secondary)
                    TextField("username".localized, text: $vm.username)
                        .font(.system(size: 16))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .glassTextField()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("bio".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("bio".localized, text: $vm.bio, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(3...6)
                    .glassTextField()
            }

            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .foregroundColor(.secondary)
                Text(vm.user?.phone ?? "")
                    .font(.system(size: 16))
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .glassTextField()
        }
        .glassCard()
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                vm.selectedImageData = data
            }
        }
    }
}
