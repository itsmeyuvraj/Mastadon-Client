import SwiftUI

// MARK: - Tab

enum AppTab: String, CaseIterable {
    case timeline = "Timeline"
    case profile  = "Profile"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .timeline: return "house.fill"
        case .profile:  return "person.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var selectedTab: AppTab = .timeline

    var body: some View {
        if auth.isAuthenticated {
            mainContent
                .task { await loadAccount() }
        } else {
            LoginView()
        }
    }

    // MARK: - Main App Shell

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            MeshGradientBackground()

            VStack(spacing: 0) {
                // Header
                header

                Divider().opacity(0.2)

                // Content area
                ZStack {
                    switch selectedTab {
                    case .timeline:
                        FeedView()
                            .transition(.opacity)
                    case .profile:
                        ProfileView()
                            .transition(.opacity)
                    case .settings:
                        SettingsView()
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().opacity(0.2)

                // Bottom tab bar
                tabBar
            }
        }
        .frame(width: 400, height: 600)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // Avatar
            if let account = auth.currentAccount {
                CachedAsyncImage(url: account.avatar, cornerRadius: 16)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                    }
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 1) {
                if let account = auth.currentAccount {
                    Text(account.displayName.isEmpty ? account.username : account.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("@\(account.acct)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Mastodon")
                        .font(.system(size: 13, weight: .semibold))
                }
            }

            Spacer()

            // Instance badge
            Text(auth.instanceURL)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(.white.opacity(0.12))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                }
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                Spacer()
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }
                )
                Spacer()
            }
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Load Account

    private func loadAccount() async {
        guard auth.currentAccount == nil else { return }
        if let account = try? await MastodonAPI.shared.verifyCredentials() {
            auth.currentAccount = account
        }
    }
}

// MARK: - Tab Bar Item

struct TabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Color(hue: 0.65, saturation: 0.6, brightness: 0.6).opacity(0.4))
                            .frame(width: 44, height: 26)
                            .overlay {
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [Color.white.opacity(0.15), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                            }
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                            }
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected
                                         ? Color(hue: 0.65, saturation: 0.2, brightness: 1.0)
                                         : Color.secondary)
                        .frame(width: 44, height: 26)
                }

                Text(tab.rawValue)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var account: Account?
    @State private var statuses: [Status] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let account = account ?? auth.currentAccount {
                    profileHeader(account)

                    Divider().opacity(0.2).padding(.vertical, 8)

                    LazyVStack(spacing: 8) {
                        ForEach(statuses) { status in
                            StatusRowView(status: status)
                        }
                    }
                    .padding(.horizontal, 12)
                } else {
                    ProgressView().padding(40)
                }
            }
            .padding(.bottom, 20)
        }
        .task { await loadProfile() }
    }

    private func profileHeader(_ account: Account) -> some View {
        VStack(spacing: 0) {
            // Header image
            CachedAsyncImage(url: account.header, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    CachedAsyncImage(url: account.avatar, cornerRadius: 24)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                        }
                        .shadow(radius: 8)
                        .offset(x: 16, y: 30)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.displayName.isEmpty ? account.username : account.displayName)
                            .font(.system(size: 16, weight: .bold))
                        Text("@\(account.acct)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 36)

                // Stats row
                HStack(spacing: 20) {
                    statBadge(count: account.statusesCount, label: "Toots")
                    statBadge(count: account.followingCount, label: "Following")
                    statBadge(count: account.followersCount, label: "Followers")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func statBadge(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(count.formatted(.number.notation(.compactName)))
                .font(.system(size: 14, weight: .semibold))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func loadProfile() async {
        guard let account = try? await MastodonAPI.shared.verifyCredentials() else { return }
        self.account = account
        isLoading = false
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var showLogoutConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Account section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Account")

                    if let account = auth.currentAccount {
                        HStack(spacing: 12) {
                            CachedAsyncImage(url: account.avatar, cornerRadius: 20)
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayName.isEmpty ? account.username : account.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("@\(account.acct) · \(auth.instanceURL)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .liquidGlassCard(cornerRadius: 16)
                    }

                    Button {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                            Spacer()
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .padding(14)
                        .liquidGlassCard(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                }

                // App info section
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("About")

                    VStack(spacing: 0) {
                        infoRow(label: "Version", value: "1.0")
                        Divider().opacity(0.2).padding(.leading, 14)
                        infoRow(label: "Platform", value: "macOS 26")
                        Divider().opacity(0.2).padding(.leading, 14)
                        infoRow(label: "Instance", value: auth.instanceURL)
                    }
                    .liquidGlassCard(cornerRadius: 16)
                }
            }
            .padding(16)
        }
        .alert("Sign out?", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { auth.logout() }
        } message: {
            Text("You'll need to log in again to access your feed.")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(1)
            .padding(.leading, 4)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
