import AppKit

enum MenuBarIcon {
  static var image: NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)

    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    let stroke = NSColor.labelColor
    let body = NSBezierPath(roundedRect: NSRect(x: 4, y: 2, width: 10, height: 13), xRadius: 2, yRadius: 2)
    stroke.setStroke()
    body.lineWidth = 1.6
    body.stroke()

    let clip = NSBezierPath(roundedRect: NSRect(x: 6.5, y: 13, width: 5, height: 3), xRadius: 1.2, yRadius: 1.2)
    clip.lineWidth = 1.5
    clip.stroke()

    for y in [10.5, 8.0, 5.5] {
      let line = NSBezierPath()
      line.move(to: NSPoint(x: 6, y: y))
      line.line(to: NSPoint(x: 12, y: y))
      line.lineWidth = 1
      line.stroke()
    }

    image.unlockFocus()
    image.isTemplate = true
    return image
  }
}

