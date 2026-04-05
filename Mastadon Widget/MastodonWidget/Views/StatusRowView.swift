import SwiftUI

// MARK: - Async Image

struct CachedAsyncImage: View {
    let url: String
    var cornerRadius: CGFloat = 6

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Color.gray.opacity(0.3)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            case .empty:
                Color.clear
                    .overlay { ProgressView().controlSize(.small) }
            @unknown default:
                Color.clear
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Status Row View

struct StatusRowView: View {
    let status: Status
    var onReply: ((Status) -> Void)? = nil

    @State private var isFavourited: Bool
    @State private var isReblogged: Bool
    @State private var favouriteCount: Int
    @State private var reblogCount: Int
    @State private var isActing = false

    private var effectiveStatus: Status {
        status.reblog?.value ?? status
    }

    init(status: Status, onReply: ((Status) -> Void)? = nil) {
        self.status = status
        self.onReply = onReply
        _isFavourited = State(initialValue: status.favourited ?? false)
        _isReblogged = State(initialValue: status.reblogged ?? false)
        _favouriteCount = State(initialValue: status.favouritesCount)
        _reblogCount = State(initialValue: status.reblogsCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reblog indicator
            if let reblogger = status.reblog != nil ? status.account : nil {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 11, weight: .medium))
                    Text("\(reblogger.displayName.isEmpty ? reblogger.username : reblogger.displayName) boosted")
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            }

            HStack(alignment: .top, spacing: 12) {
                // Avatar
                CachedAsyncImage(url: effectiveStatus.account.avatar, cornerRadius: 20)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    // Author & time
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(effectiveStatus.account.displayName.isEmpty
                                 ? effectiveStatus.account.username
                                 : effectiveStatus.account.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text("@\(effectiveStatus.account.acct)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(effectiveStatus.formattedDate)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    // Content
                    if !effectiveStatus.spoilerText.isEmpty {
                        DisclosureGroup {
                            Text(effectiveStatus.plainText)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        } label: {
                            Text("CW: \(effectiveStatus.spoilerText)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    } else if !effectiveStatus.plainText.isEmpty {
                        Text(effectiveStatus.plainText)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(10)
                    }

                    // Media attachments
                    if !effectiveStatus.mediaAttachments.isEmpty {
                        mediaGrid
                    }

                    // Action bar
                    HStack(spacing: 20) {
                        ActionButton(
                            icon: "bubble.left",
                            label: "\(effectiveStatus.repliesCount)",
                            isActive: false,
                            activeColor: .blue
                        ) {
                            onReply?(effectiveStatus)
                        }

                        ActionButton(
                            icon: isReblogged ? "arrow.2.squarepath" : "arrow.2.squarepath",
                            label: "\(reblogCount)",
                            isActive: isReblogged,
                            activeColor: Color(red: 0.2, green: 0.8, blue: 0.4)
                        ) {
                            toggleReblog()
                        }

                        ActionButton(
                            icon: isFavourited ? "heart.fill" : "heart",
                            label: "\(favouriteCount)",
                            isActive: isFavourited,
                            activeColor: .pink
                        ) {
                            toggleFavourite()
                        }

                        Spacer()

                        // Visibility badge
                        visibilityBadge
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: 16)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var mediaGrid: some View {
        let attachments = effectiveStatus.mediaAttachments.prefix(4)
        let count = attachments.count

        if count == 1, let att = attachments.first, let url = att.url ?? att.previewUrl {
            CachedAsyncImage(url: url, cornerRadius: 12)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
        } else if count > 1 {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(count, 2)),
                spacing: 4
            ) {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { _, att in
                    if let url = att.url ?? att.previewUrl {
                        CachedAsyncImage(url: url, cornerRadius: 8)
                            .frame(height: count <= 2 ? 140 : 100)
                            .clipped()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var visibilityBadge: some View {
        let (icon, color): (String, Color) = {
            switch effectiveStatus.visibility {
            case .public: return ("globe", .secondary)
            case .unlisted: return ("lock.open", .secondary)
            case .private: return ("lock", .orange)
            case .direct: return ("envelope", .blue)
            }
        }()

        Image(systemName: icon)
            .font(.system(size: 10))
            .foregroundStyle(color)
    }

    // MARK: - Actions

    private func toggleFavourite() {
        guard !isActing else { return }
        isActing = true
        let wasActive = isFavourited
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isFavourited.toggle()
            favouriteCount += wasActive ? -1 : 1
        }
        Task {
            do {
                _ = try await wasActive
                    ? MastodonAPI.shared.unfavourite(id: effectiveStatus.id)
                    : MastodonAPI.shared.favourite(id: effectiveStatus.id)
            } catch {
                await MainActor.run {
                    withAnimation { isFavourited = wasActive; favouriteCount += wasActive ? 1 : -1 }
                }
            }
            await MainActor.run { isActing = false }
        }
    }

    private func toggleReblog() {
        guard !isActing else { return }
        isActing = true
        let wasActive = isReblogged
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isReblogged.toggle()
            reblogCount += wasActive ? -1 : 1
        }
        Task {
            do {
                _ = try await wasActive
                    ? MastodonAPI.shared.unreblog(id: effectiveStatus.id)
                    : MastodonAPI.shared.reblog(id: effectiveStatus.id)
            } catch {
                await MainActor.run {
                    withAnimation { isReblogged = wasActive; reblogCount += wasActive ? 1 : -1 }
                }
            }
            await MainActor.run { isActing = false }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isPressed = false
            }
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                if label != "0" {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundStyle(isActive ? activeColor : .secondary)
            .scaleEffect(isPressed ? 1.2 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
