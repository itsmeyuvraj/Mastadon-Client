import Foundation

// MARK: - Streaming Service

@MainActor
final class StreamingService: ObservableObject {
    @Published var newStatuses: [Status] = []
    @Published var isConnected = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectTask: Task<Void, Never>?

    func connect() {
        guard let streamURL = try? MastodonAPI.shared.streamingURL() else {
            return
        }
        disconnect()

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: streamURL)
        webSocketTask?.resume()
        isConnected = true

        startPing()
        receiveMessage()
    }

    func disconnect() {
        reconnectTask?.cancel()
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveMessage()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        var text: String
        switch message {
        case .string(let str): text = str
        case .data(let data): text = String(data: data, encoding: .utf8) ?? ""
        @unknown default: return
        }

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String,
              event == "update",
              let payload = json["payload"] as? String,
              let payloadData = payload.data(using: .utf8),
              let status = try? JSONDecoder().decode(Status.self, from: payloadData)
        else { return }

        newStatuses.insert(status, at: 0)
        // Keep buffer small
        if newStatuses.count > 50 { newStatuses.removeLast() }
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.webSocketTask?.sendPing { _ in }
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            connect()
        }
    }
}
