import Cocoa

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
