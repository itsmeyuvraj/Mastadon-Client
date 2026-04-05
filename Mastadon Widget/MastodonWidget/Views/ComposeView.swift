import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Compose View

struct ComposeView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    var replyTo: Status? = nil
    var onPost: ((Status) -> Void)? = nil

    @State private var text = ""
    @State private var selectedImages: [NSImage] = []
    @State private var uploadedMediaIds: [String] = []
    @State private var visibility: Status.Visibility = .public
    @State private var spoilerText = ""
    @State private var showContentWarning = false
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var isUploadingImages = false
    @State private var showImagePicker = false

    private let maxCharacters = 500

    private var remainingCharacters: Int {
        maxCharacters - text.count - spoilerText.count
    }

    private var canPost: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty)
        && remainingCharacters >= 0
        && !isPosting
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
                .opacity(0.7)

            VStack(spacing: 0) {
                // Toolbar
                toolbar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)

                Divider().opacity(0.3)

                ScrollView {
                    VStack(spacing: 12) {
                        // Reply context
                        if let reply = replyTo {
                            replyContext(reply)
                        }

                        // Content warning
                        if showContentWarning {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 13))

                                TextField("Content warning…", text: $spoilerText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                            }
                            .padding(12)
                            .liquidGlassBackground(cornerRadius: 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Text area
                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text(replyTo != nil ? "Write your reply…" : "What's on your mind?")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                                    .padding(.leading, 0)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $text)
                                .font(.system(size: 14))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .frame(minHeight: 120)
                        }
                        .padding(14)
                        .liquidGlassBackground(cornerRadius: 14)

                        // Image previews
                        if !selectedImages.isEmpty {
                            imagePreviewGrid
                        }

                        // Error
                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error)
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.red)
                            .padding(10)
                            .liquidGlassBackground(cornerRadius: 10)
                            .transition(.opacity)
                        }
                    }
                    .padding(16)
                }

                Divider().opacity(0.3)

                // Bottom bar
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
            }
        }
        .frame(width: 420, height: 500)
        .onAppear {
            if let reply = replyTo {
                text = "@\(reply.account.acct) "
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(replyTo != nil ? "Reply" : "New Toot")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: post) {
                HStack(spacing: 6) {
                    if isPosting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(isPosting ? "Posting…" : "Toot!")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background {
                    Capsule(style: .continuous)
                        .fill(canPost
                              ? Color(hue: 0.65, saturation: 0.7, brightness: 0.7)
                              : Color.gray.opacity(0.4))
                        .overlay {
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                        }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canPost)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Image picker
            Button {
                pickImages()
            } label: {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(selectedImages.count >= 4 ? .tertiary : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(selectedImages.count >= 4 || isUploadingImages)
            .help("Attach image (max 4)")

            // Content warning toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showContentWarning.toggle()
                    if !showContentWarning { spoilerText = "" }
                }
            } label: {
                Image(systemName: showContentWarning ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(showContentWarning ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help("Content warning")

            // Visibility picker
            Menu {
                ForEach([Status.Visibility.public, .unlisted, .private, .direct], id: \.rawValue) { vis in
                    Button {
                        visibility = vis
                    } label: {
                        Label(vis.label, systemImage: vis.icon)
                    }
                }
            } label: {
                Image(systemName: visibility.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Visibility: \(visibility.label)")

            Spacer()

            // Character counter
            let remaining = remainingCharacters
            Text("\(remaining)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(
                    remaining < 0 ? .red :
                    remaining < 20 ? .orange :
                    .secondary
                )
        }
    }

    // MARK: - Reply Context

    private func replyContext(_ status: Status) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                CachedAsyncImage(url: status.account.avatar, cornerRadius: 14)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())

                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1.5)
                    .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(status.account.displayName.isEmpty ? status.account.username : status.account.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(status.plainText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(10)
        .liquidGlassBackground(cornerRadius: 12)
    }

    // MARK: - Image Preview Grid

    private var imagePreviewGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2),
            spacing: 6
        ) {
            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button {
                        selectedImages.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
        }
    }

    // MARK: - Actions

    private func pickImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.jpeg, .png, .gif, .webP]
        panel.message = "Choose up to \(4 - selectedImages.count) images"

        if panel.runModal() == .OK {
            let remaining = 4 - selectedImages.count
            let newImages = panel.urls.prefix(remaining).compactMap { NSImage(contentsOf: $0) }
            withAnimation { selectedImages.append(contentsOf: newImages) }
        }
    }

    private func post() {
        isPosting = true
        errorMessage = nil

        Task {
            do {
                // Upload images first
                var mediaIds: [String] = []
                if !selectedImages.isEmpty {
                    isUploadingImages = true
                    for image in selectedImages {
                        if let data = image.jpegData(compressionQuality: 0.85) {
                            let uploaded = try await MastodonAPI.shared.uploadMedia(imageData: data)
                            mediaIds.append(uploaded.id)
                        }
                    }
                    isUploadingImages = false
                }

                // Post the status
                let posted = try await MastodonAPI.shared.postStatus(
                    text: text,
                    mediaIds: mediaIds,
                    visibility: visibility,
                    sensitive: showContentWarning,
                    spoilerText: spoilerText,
                    replyToId: replyTo?.id
                )

                await MainActor.run {
                    onPost?(posted)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isPosting = false
                    isUploadingImages = false
                }
            }
        }
    }
}

// MARK: - Extensions

extension Status.Visibility {
    var label: String {
        switch self {
        case .public: return "Public"
        case .unlisted: return "Unlisted"
        case .private: return "Followers only"
        case .direct: return "Direct"
        }
    }

    var icon: String {
        switch self {
        case .public: return "globe"
        case .unlisted: return "lock.open"
        case .private: return "lock"
        case .direct: return "envelope"
        }
    }
}

extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
