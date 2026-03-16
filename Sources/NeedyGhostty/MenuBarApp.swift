import Cocoa
import NeedyGhosttyCore

let menuWidth: CGFloat = 440
let padX: CGFloat = 20

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var dirWatcher: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var notifications: [NotificationEntry] = []
    private let store = NotificationStore(dataDir: dataDir)
    private let ghostty = GhosttyBridge()

    private var nativeNotificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "nativeNotifications") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "nativeNotifications") }
    }

    private var autoDismissEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "autoDismiss") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoDismiss") }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        loadNotifications()
        setupDirectoryWatcher()
        setupWorkspaceObserver()
        if autoDismissEnabled, NSWorkspace.shared.frontmostApplication?.localizedName == "Ghostty" {
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
        if let img = NSImage(systemSymbolName: sym, accessibilityDescription: "NeedyGhostty") {
            img.isTemplate = true
            button.image = img
        }
        if count > 0 {
            button.attributedTitle = NSAttributedString(
                string: " \(count)",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                    .baselineOffset: 0.5,
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
                    self?.ghostty.focusTerminal(tid)
                    self?.removeNotification(sessionId: sid)
                }
                item.view = view
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let toggle = NSMenuItem(
            title: "  macOS Notifications",
            action: #selector(toggleNativeNotifications(_:)),
            keyEquivalent: "")
        toggle.target = self
        toggle.state = nativeNotificationsEnabled ? .on : .off
        menu.addItem(toggle)

        let autoDismiss = NSMenuItem(
            title: "  Auto-dismiss on Focus",
            action: #selector(toggleAutoDismiss(_:)),
            keyEquivalent: "")
        autoDismiss.target = self
        autoDismiss.state = autoDismissEnabled ? .on : .off
        menu.addItem(autoDismiss)

        menu.addItem(NSMenuItem.separator())

        let clear = NSMenuItem(
            title: "  Clear All",
            action: #selector(clearAll(_:)),
            keyEquivalent: "")
        clear.target = self
        clear.isEnabled = !notifications.isEmpty
        menu.addItem(clear)

        let quit = NSMenuItem(
            title: "  Quit NeedyGhostty",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        let spacer = NSMenuItem()
        spacer.view = NSView(frame: NSRect(x: 0, y: 0, width: menuWidth, height: 2))
        spacer.isEnabled = false
        menu.addItem(spacer)
    }

    // MARK: - Actions

    @objc private func toggleNativeNotifications(_ sender: NSMenuItem) {
        nativeNotificationsEnabled.toggle()
    }

    @objc private func toggleAutoDismiss(_ sender: NSMenuItem) {
        autoDismissEnabled.toggle()
        if autoDismissEnabled, NSWorkspace.shared.frontmostApplication?.localizedName == "Ghostty" {
            startPolling()
        } else if !autoDismissEnabled {
            stopPolling()
        }
    }

    @objc private func clearAll(_ sender: NSMenuItem) {
        notifications.removeAll()
        store.save([])
        updateBadge()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }

    // MARK: - Notifications I/O

    private func loadNotifications() {
        let oldIds = Set(notifications.map(\.session_id))
        notifications = store.load()

        if nativeNotificationsEnabled {
            for notif in notifications where !oldIds.contains(notif.session_id) {
                let dir = (notif.cwd as NSString).lastPathComponent
                ghostty.sendNotification(
                    title: "Claude Code \u{2014} \(dir)",
                    message: notif.message)
            }
        }

        updateBadge()
    }

    private func removeNotification(sessionId: String) {
        notifications.removeAll { $0.session_id == sessionId }
        store.save(notifications)
        updateBadge()
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
        guard autoDismissEnabled, isGhostty(notification) else { return }
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
            guard let tid = self?.ghostty.getFocusedTerminalId(),
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
