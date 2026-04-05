import SwiftUI

// MARK: - Timeline View Model

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published var statuses: [Status] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var hasMore = true

    private let streaming = StreamingService()
    private var loadTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?

    init() {
        startPolling()
    }

    // Poll StreamingService for new toots every 500ms
    // (avoids Combine AsyncPublisher which has Swift 6 isolation warnings)
    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { return }
                guard !streaming.newStatuses.isEmpty else { continue }
                let incoming = streaming.newStatuses
                streaming.newStatuses.removeAll()
                let existingIds = Set(statuses.map(\.id))
                let fresh = incoming.filter { !existingIds.contains($0.id) }
                guard !fresh.isEmpty else { continue }
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.statuses.insert(contentsOf: fresh, at: 0)
                }
            }
        }
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        loadTask = Task {
            do {
                let fetched = try await MastodonAPI.shared.homeTimeline(limit: 30)
                statuses = fetched
                hasMore = fetched.count >= 30
                streaming.connect()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        do {
            let fetched = try await MastodonAPI.shared.homeTimeline(limit: 30)
            withAnimation { statuses = fetched }
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    func loadMore() async {
        guard hasMore, !isLoading, let last = statuses.last else { return }
        isLoading = true
        do {
            let more = try await MastodonAPI.shared.homeTimeline(maxId: last.id, limit: 20)
            statuses.append(contentsOf: more)
            hasMore = more.count >= 20
        } catch {
            // Silent failure for pagination
        }
        isLoading = false
    }

    func prependNewStatus(_ status: Status) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            statuses.insert(status, at: 0)
        }
    }

    deinit {
        loadTask?.cancel()
        pollingTask?.cancel()
        // streaming is @MainActor — schedule disconnect asynchronously
        let s = streaming
        Task { @MainActor in s.disconnect() }
    }
}

// MARK: - Feed View

struct FeedView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var showCompose = false
    @State private var replyTarget: Status?
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var newPostCount = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Top anchor for scroll-to-top
                        Color.clear.frame(height: 1).id("top")

                        if viewModel.isLoading && viewModel.statuses.isEmpty {
                            loadingPlaceholder
                        } else if let error = viewModel.errorMessage, viewModel.statuses.isEmpty {
                            errorView(error)
                        } else if viewModel.statuses.isEmpty {
                            emptyView
                        } else {
                            ForEach(viewModel.statuses) { status in
                                StatusRowView(status: status) { toReply in
                                    replyTarget = toReply
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                                .onAppear {
                                    if status.id == viewModel.statuses.last?.id {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                            }

                            if viewModel.isLoading && !viewModel.statuses.isEmpty {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
                .refreshable { await viewModel.refresh() }
                .onAppear {
                    scrollProxy = proxy
                    viewModel.load()
                }
            }

            // Floating compose button
            HStack {
                Spacer()
                composeButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeView { newStatus in
                viewModel.prependNewStatus(newStatus)
            }
        }
        .sheet(item: $replyTarget) { status in
            ComposeView(replyTo: status) { newStatus in
                viewModel.prependNewStatus(newStatus)
            }
        }
    }

    // MARK: - Sub-views

    private var loadingPlaceholder: some View {
        VStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(height: 100)
                    .shimmer()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") { viewModel.load() }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .pillButton(color: Color(hue: 0.65, saturation: 0.7, brightness: 0.7))
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No toots yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Your home timeline is empty.\nFollow some accounts to get started.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var composeButton: some View {
        Button {
            showCompose = true
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hue: 0.65, saturation: 0.8, brightness: 0.8),
                                        Color(hue: 0.75, saturation: 0.7, brightness: 0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
                    }
                    .shadow(
                        color: Color(hue: 0.65, saturation: 0.7, brightness: 0.6).opacity(0.5),
                        radius: 12, x: 0, y: 6
                    )

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCompose)
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: phase - 0.3),
                        .init(color: .white.opacity(0.08), location: phase),
                        .init(color: .clear, location: phase + 0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
