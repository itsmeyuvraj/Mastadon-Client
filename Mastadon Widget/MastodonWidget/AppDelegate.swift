import AppKit
import SwiftUI

// MARK: - App Delegate (Menu Bar Setup)

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: EventMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app to not appear in Dock
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
    }

    // MARK: - Menu Bar

    @MainActor private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "bubble.left.and.bubble.right.fill",
                accessibilityDescription: "Mastodon"
            )
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        setupPopover()
        setupEventMonitor()
    }

    @MainActor private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        popover.animates = true

        let contentView = ContentView()
            .environmentObject(AuthManager.shared)

        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            openPopover(relativeTo: button)
        }
    }

    private func openPopover(relativeTo button: NSStatusBarButton) {
        popover?.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
        eventMonitor?.start()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover?.performClose(nil)
        eventMonitor?.stop()
    }

    // MARK: - Event Monitor (click outside to close)

    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover?.isShown == true else { return }
            self.closePopover()
        }
    }
}

// MARK: - Event Monitor Helper

final class EventMonitor {
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    private var monitor: Any?

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit { stop() }
}
