import Cocoa

// MARK: - Data Model

struct NotificationEntry: Codable {
    let session_id: String
    let terminal_id: String
    let working_dir: String
    let cwd: String
    let name: String
    var message: String
    var timestamp: String
}

// MARK: - Constants

let menuWidth: CGFloat = 440
let padX: CGFloat = 20
let dataDir: String = {
    let dir = NSHomeDirectory() + "/.local/share/ghostty-notify"
    try? FileManager.default.createDirectory(
        atPath: dir, withIntermediateDirectories: true)
    return dir
}()
let notifFilePath = dataDir + "/notifications.json"
let lockPath = "/tmp/ghostty-notify.lock"

// MARK: - Helpers

func acquireLock() -> Bool {
    for attempt in 0..<100 {
        do {
            try FileManager.default.createDirectory(
                atPath: lockPath, withIntermediateDirectories: false)
            return true
        } catch {
            // Every 500ms, check if lock is stale (older than 10s)
            if attempt % 10 == 0,
                let attrs = try? FileManager.default.attributesOfItem(atPath: lockPath),
                let modDate = attrs[.modificationDate] as? Date,
                Date().timeIntervalSince(modDate) > 10
            {
                try? FileManager.default.removeItem(atPath: lockPath)
                continue
            }
            usleep(50_000)
        }
    }
    return false
}

func releaseLock() {
    try? FileManager.default.removeItem(atPath: lockPath)
}

func relativeTime(_ iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    guard let date = f.date(from: iso) else { return "" }
    let s = Int(-date.timeIntervalSinceNow)
    if s < 10 { return "just now" }
    if s < 60 { return "\(s)s ago" }
    if s < 3600 { return "\(s / 60)m ago" }
    if s < 86400 { return "\(s / 3600)h ago" }
    return "\(s / 86400)d ago"
}

func dotColor(for message: String) -> NSColor {
    let m = message.lowercased()
    if m.contains("permission") || m.contains("question") { return .systemBlue }
    return .systemGreen
}

// MARK: - Custom Menu Views

class NotificationItemView: NSView {
    private let projectLabel = NSTextField(labelWithString: "")
    private let messageLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var stripeColor: NSColor = .systemGreen
    private var showDivider = false
    var onClick: (() -> Void)?

    init(entry: NotificationEntry, showDivider: Bool) {
        self.showDivider = showDivider
        super.init(frame: NSRect(x: 0, y: 0, width: menuWidth, height: 70))
        setup(entry)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup(_ entry: NotificationEntry) {
        stripeColor = dotColor(for: entry.message)

        // Project name
        let dir = (entry.cwd as NSString).lastPathComponent
        projectLabel.font = .systemFont(ofSize: 15, weight: .bold)
        projectLabel.textColor = .labelColor
        projectLabel.lineBreakMode = .byTruncatingTail
        projectLabel.stringValue = dir
        addSubview(projectLabel)

        // Relative time
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.alignment = .right
        timeLabel.stringValue = relativeTime(entry.timestamp)
        addSubview(timeLabel)

        // Message
        messageLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.stringValue = entry.message
        addSubview(messageLabel)
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        let textX: CGFloat = padX + 14

        projectLabel.frame = NSRect(x: textX, y: h - 32, width: w - textX - 80, height: 20)
        timeLabel.frame = NSRect(x: w - padX - 60, y: h - 30, width: 56, height: 16)
        messageLabel.frame = NSRect(x: textX, y: h - 54, width: w - textX - padX, height: 18)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Hover background
        if isHovered {
            NSColor.controlAccentColor.withAlphaComponent(0.08).setFill()
            bounds.fill()
        }

        // Left stripe (drawn dynamically for dark/light mode)
        stripeColor.setFill()
        let stripeRect = NSRect(x: padX - 4, y: 8, width: 3, height: bounds.height - 16)
        NSBezierPath(roundedRect: stripeRect, xRadius: 1.5, yRadius: 1.5).fill()

        // Bottom divider
        if showDivider {
            NSColor.separatorColor.withAlphaComponent(0.3).setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: 0.5).fill()
        }

        super.draw(dirtyRect)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSCursor.pointingHand.push()
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSCursor.pop()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        onClick?()
        enclosingMenuItem?.menu?.cancelTracking()
    }
}

class HeaderView: NSView {
    init(count: Int) {
        super.init(frame: NSRect(x: 0, y: 0, width: menuWidth, height: 40))

        let label = NSTextField(labelWithString: "")
        let text = count > 0 ? "WAITING \u{00B7} \(count)" : "ALL CLEAR"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .kern: 1.8
        ]
        label.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
        label.frame = NSRect(x: padX, y: 8, width: menuWidth - padX * 2, height: 18)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.separatorColor.setFill()
        NSRect(x: padX, y: 0, width: bounds.width - padX * 2, height: 1).fill()
    }
}

class EmptyStateView: NSView {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: menuWidth, height: 80))

        let iconView = NSImageView()
        if let img = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .light)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = .systemGreen
        }
        iconView.frame = NSRect(x: menuWidth / 2 - 14, y: 38, width: 28, height: 28)
        addSubview(iconView)

        let label = NSTextField(labelWithString: "No sessions waiting")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 16, width: menuWidth, height: 20)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var dirWatcher: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var notifications: [NotificationEntry] = []

    private var nativeNotificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "nativeNotifications") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "nativeNotifications") }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        loadNotifications()
        setupDirectoryWatcher()
        setupWorkspaceObserver()
        if NSWorkspace.shared.frontmostApplication?.localizedName == "Ghostty" {
            startPolling()
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            updateButtonAppearance(button)
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func updateButtonAppearance(_ button: NSStatusBarButton) {
        let count = notifications.count
        let sym = count > 0 ? "terminal.fill" : "terminal"
        if let img = NSImage(systemSymbolName: sym, accessibilityDescription: "GhosttyNotify") {
            img.isTemplate = true
            button.image = img
        }
        if count > 0 {
            button.attributedTitle = NSAttributedString(
                string: " \(count)",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                    .baselineOffset: 0.5
                ])
        } else {
            button.title = ""
        }
    }

    private func updateBadge() {
        if let button = statusItem.button {
            updateButtonAppearance(button)
        }
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        loadNotifications()
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.minimumWidth = menuWidth

        // Header
        let headerItem = NSMenuItem()
        headerItem.view = HeaderView(count: notifications.count)
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        if notifications.isEmpty {
            let emptyItem = NSMenuItem()
            emptyItem.view = EmptyStateView()
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (i, notif) in notifications.enumerated() {
                let item = NSMenuItem()
                let isLast = i == notifications.count - 1
                let view = NotificationItemView(entry: notif, showDivider: !isLast)
                let sid = notif.session_id
                let tid = notif.terminal_id
                view.onClick = { [weak self] in
                    self?.focusTerminal(tid)
                    self?.removeNotification(sessionId: sid)
                }
                item.view = view
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Toggle
        let toggle = NSMenuItem(
            title: "  macOS Notifications",
            action: #selector(toggleNativeNotifications(_:)),
            keyEquivalent: "")
        toggle.target = self
        toggle.state = nativeNotificationsEnabled ? .on : .off
        menu.addItem(toggle)

        menu.addItem(NSMenuItem.separator())

        let clear = NSMenuItem(
            title: "  Clear All",
            action: #selector(clearAll(_:)),
            keyEquivalent: "")
        clear.target = self
        clear.isEnabled = !notifications.isEmpty
        menu.addItem(clear)

        let quit = NSMenuItem(
            title: "  Quit GhosttyNotify",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Bottom spacer
        let spacer = NSMenuItem()
        spacer.view = NSView(frame: NSRect(x: 0, y: 0, width: menuWidth, height: 2))
        spacer.isEnabled = false
        menu.addItem(spacer)
    }

    // MARK: - Actions

    @objc private func toggleNativeNotifications(_ sender: NSMenuItem) {
        nativeNotificationsEnabled.toggle()
    }

    @objc private func clearAll(_ sender: NSMenuItem) {
        notifications.removeAll()
        writeNotifications()
        updateBadge()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    // MARK: - Ghostty AppleScript

    private func focusTerminal(_ terminalId: String) {
        let escaped = terminalId.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
            tell application "Ghostty"
                activate
                focus (first terminal whose id is "\(escaped)")
            end tell
            """
        runOsascriptAsync(script)
    }

    private func getFocusedTerminalId() -> String? {
        let script = """
            tell application "Ghostty"
                return id of focused terminal of selected tab of front window
            end tell
            """
        return runOsascriptSync(script)
    }

    private func runOsascriptAsync(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            try? task.run()
        }
    }

    private func runOsascriptSync(_ script: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Notifications I/O

    private func loadNotifications() {
        guard FileManager.default.fileExists(atPath: notifFilePath),
            let data = FileManager.default.contents(atPath: notifFilePath)
        else {
            notifications = []
            updateBadge()
            return
        }

        let oldIds = Set(notifications.map(\.session_id))

        do {
            notifications = try JSONDecoder().decode([NotificationEntry].self, from: data)
        } catch {
            notifications = []
        }

        if nativeNotificationsEnabled {
            for notif in notifications where !oldIds.contains(notif.session_id) {
                sendNativeNotification(notif)
            }
        }

        updateBadge()
    }

    private func writeNotifications() {
        guard acquireLock() else { return }
        defer { releaseLock() }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(notifications)
            let tmpURL = URL(fileURLWithPath: "/tmp/ghostty-notify-\(UUID().uuidString).json")
            try data.write(to: tmpURL)
            _ = try FileManager.default.replaceItemAt(
                URL(fileURLWithPath: notifFilePath), withItemAt: tmpURL)
        } catch {
            if let data = try? JSONEncoder().encode(notifications) {
                try? data.write(to: URL(fileURLWithPath: notifFilePath))
            }
        }
    }

    private func removeNotification(sessionId: String) {
        notifications.removeAll { $0.session_id == sessionId }
        writeNotifications()
        updateBadge()
    }

    // MARK: - Native macOS Notifications

    private func sendNativeNotification(_ entry: NotificationEntry) {
        let dir = (entry.cwd as NSString).lastPathComponent
        let title = "Claude Code \u{2014} \(dir)"
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let msg = entry.message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        runOsascriptAsync(
            "display notification \"\(msg)\" with title \"\(title)\"")
    }

    // MARK: - File Watching

    private func setupDirectoryWatcher() {
        let fd = open(dataDir, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main)

        source.setEventHandler { [weak self] in
            self?.loadNotifications()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        dirWatcher = source
    }

    // MARK: - Stale Notification Detection

    private func setupWorkspaceObserver() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(
            self, selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(
            self, selector: #selector(appDidDeactivate(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard isGhostty(notification) else { return }
        startPolling()
    }

    @objc private func appDidDeactivate(_ notification: Notification) {
        guard isGhostty(notification) else { return }
        stopPolling()
    }

    private func isGhostty(_ notification: Notification) -> Bool {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        else { return false }
        return app.localizedName == "Ghostty"
            || app.bundleIdentifier == "com.mitchellh.ghostty"
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: 2.0, repeats: true
        ) { [weak self] _ in
            self?.checkFocusedTerminal()
        }
        checkFocusedTerminal()
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkFocusedTerminal() {
        guard !notifications.isEmpty else {
            stopPolling()
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let tid = self?.getFocusedTerminalId(),
                !tid.isEmpty
            else { return }

            DispatchQueue.main.async {
                guard let self = self,
                    let match = self.notifications.first(where: { $0.terminal_id == tid })
                else { return }
                self.removeNotification(sessionId: match.session_id)
            }
        }
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
