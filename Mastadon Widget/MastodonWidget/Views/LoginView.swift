import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var instanceText = ""
    @State private var isAnimating = false

    // Popular instances for quick selection
    private let popularInstances = [
        "mastodon.social",
        "fosstodon.org",
        "hachyderm.io",
        "infosec.exchange",
        "mas.to"
    ]

    var body: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: 0) {
                Spacer()

                // Logo & Title
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
                            }
                            .shadow(color: Color(hue: 0.65, saturation: 0.8, brightness: 0.6).opacity(0.5), radius: 20)

                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color.white.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(isAnimating ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

                    VStack(spacing: 6) {
                        Text("Mastodon")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Connect to your instance")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 36)

                // Login card
                VStack(spacing: 20) {
                    // Instance input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instance")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(1)

                        HStack(spacing: 12) {
                            Image(systemName: "at")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))

                            TextField("mastodon.social", text: $instanceText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15))
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                                .onSubmit { startLogin() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .liquidGlassBackground(cornerRadius: 14)
                    }

                    // Error message
                    if let error = auth.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.red.opacity(0.12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.red.opacity(0.25), lineWidth: 0.5)
                                }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Sign in button
                    Button(action: startLogin) {
                        HStack(spacing: 10) {
                            if auth.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16))
                            }
                            Text(auth.isLoading ? "Connecting…" : "Sign In")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .pillButton(color: Color(hue: 0.65, saturation: 0.7, brightness: 0.7))
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isLoading || instanceText.trimmingCharacters(in: .whitespaces).isEmpty)

                    // Divider
                    HStack {
                        Rectangle().fill(.white.opacity(0.15)).frame(height: 0.5)
                        Text("or pick one")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 10)
                        Rectangle().fill(.white.opacity(0.15)).frame(height: 0.5)
                    }

                    // Popular instances
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(popularInstances, id: \.self) { instance in
                            Button {
                                instanceText = instance
                                Task { await auth.login(instance: instance) }
                            } label: {
                                Text(instance)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .liquidGlassBackground(cornerRadius: 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(24)
                .liquidGlassCard(cornerRadius: 24)
                .padding(.horizontal, 24)

                Spacer()

                // Footer
                Text("Mastodon Widget • macOS 26")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 380, height: 560)
        .onAppear { isAnimating = true }
    }

    private func startLogin() {
        guard !instanceText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { await auth.login(instance: instanceText) }
    }
}

// Preview macro requires Xcode — omitted for CLI builds
