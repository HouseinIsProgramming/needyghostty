import Cocoa
import NeedyGhosttyCore

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
        switch NotificationType(message: entry.message) {
        case .action: stripeColor = .systemBlue
        case .idle: stripeColor = .systemGreen
        }

        let dir = (entry.cwd as NSString).lastPathComponent
        projectLabel.font = .systemFont(ofSize: 15, weight: .bold)
        projectLabel.textColor = .labelColor
        projectLabel.lineBreakMode = .byTruncatingTail
        projectLabel.stringValue = dir
        addSubview(projectLabel)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.alignment = .right
        timeLabel.stringValue = relativeTime(entry.timestamp)
        addSubview(timeLabel)

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
        if isHovered {
            NSColor.controlAccentColor.withAlphaComponent(0.08).setFill()
            bounds.fill()
        }

        stripeColor.setFill()
        let stripeRect = NSRect(x: padX - 4, y: 8, width: 3, height: bounds.height - 16)
        NSBezierPath(roundedRect: stripeRect, xRadius: 1.5, yRadius: 1.5).fill()

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
