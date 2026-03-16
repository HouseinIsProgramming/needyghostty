import Cocoa

class HeaderView: NSView {
    init(count: Int) {
        super.init(frame: NSRect(x: 0, y: 0, width: menuWidth, height: 40))

        let label = NSTextField(labelWithString: "")
        let text = count > 0 ? "WAITING \u{00B7} \(count)" : "ALL CLEAR"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .kern: 1.8,
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
