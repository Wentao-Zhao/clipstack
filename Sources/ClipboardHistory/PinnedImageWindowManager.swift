import AppKit

@MainActor
final class PinnedImageWindowManager {
  private var windows: [PinnedImageWindowController] = []
  private var nextOffset: CGFloat = 0

  func show(image: NSImage, style: PinnedImageStyle) {
    let controller = PinnedImageWindowController(image: image, style: style)
    controller.onClose = { [weak self, weak controller] in
      guard let controller else {
        return
      }
      self?.windows.removeAll { $0 === controller }
    }

    windows.append(controller)
    controller.show(offset: nextOffset)
    nextOffset = (nextOffset + 28).truncatingRemainder(dividingBy: 196)
  }
}

struct PinnedImageStyle {
  let background: NSColor
  let accent: NSColor
  let border: NSColor
}

@MainActor
private final class PinnedImageWindowController: NSWindowController, NSWindowDelegate {
  var onClose: (() -> Void)?

  private let image: NSImage
  private let style: PinnedImageStyle

  init(image: NSImage, style: PinnedImageStyle) {
    self.image = image
    self.style = style

    let window = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = ""
    window.titleVisibility = .hidden
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.backgroundColor = .clear
    window.isOpaque = false
    window.isReleasedWhenClosed = false
    window.hidesOnDeactivate = false
    window.isMovableByWindowBackground = true
    window.minSize = NSSize(width: 220, height: 160)
    window.titlebarAppearsTransparent = true

    super.init(window: window)

    window.delegate = self
    buildContent(in: window)
    configureWindowControls(in: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  func show(offset: CGFloat) {
    guard let window else {
      return
    }

    window.setFrame(Self.defaultFrame(for: image, offset: offset), display: false)
    configureWindowControls(in: window)
    window.makeKeyAndOrderFront(nil)

    DispatchQueue.main.async { [weak self, weak window] in
      guard let self, let window else {
        return
      }
      self.configureWindowControls(in: window)
    }
  }

  func windowWillClose(_ notification: Notification) {
    onClose?()
  }

  func windowDidResize(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else {
      return
    }

    configureWindowControls(in: window)
  }

  private func buildContent(in window: NSWindow) {
    let frameView = PinnedImageFrameView(style: style)

    let imageView = NSImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.image = image
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.wantsLayer = true
    imageView.layer?.cornerRadius = 12
    imageView.layer?.masksToBounds = true

    frameView.addSubview(imageView)
    window.contentView = frameView

    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 12),
      imageView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -12),
      imageView.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 32),
      imageView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor, constant: -12),
    ])
  }

  private func configureWindowControls(in window: NSWindow) {
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    layoutCloseButton(in: window)
  }

  private func layoutCloseButton(in window: NSWindow) {
    guard
      let closeButton = window.standardWindowButton(.closeButton),
      let container = closeButton.superview
    else {
      return
    }

    let leftInset: CGFloat = 24
    let topInset: CGFloat = 16
    let y = max(container.bounds.height - closeButton.frame.height - topInset, 8)
    closeButton.setFrameOrigin(NSPoint(x: leftInset, y: y))
  }

  private static func defaultFrame(for image: NSImage, offset: CGFloat) -> NSRect {
    let visibleFrame = NSScreen.main?.visibleFrame
      ?? NSScreen.screens.first?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    let imageSize = image.size
    let aspectRatio = imageSize.width > 0 && imageSize.height > 0
      ? imageSize.width / imageSize.height
      : 4 / 3

    let maxWidth = min(visibleFrame.width * 0.42, 560)
    let maxHeight = min(visibleFrame.height * 0.46, 460)
    var width = maxWidth
    var height = width / aspectRatio

    if height > maxHeight {
      height = maxHeight
      width = height * aspectRatio
    }

    width = min(max(width, 260), maxWidth)
    height = min(max(height, 180), maxHeight)

    let centeredX = visibleFrame.midX - width / 2 + offset
    let centeredY = visibleFrame.midY - height / 2 - offset
    let x = min(max(centeredX, visibleFrame.minX + 20), visibleFrame.maxX - width - 20)
    let y = min(max(centeredY, visibleFrame.minY + 20), visibleFrame.maxY - height - 20)

    return NSRect(x: x, y: y, width: width, height: height)
  }
}

private final class PinnedImageFrameView: NSView {
  private let style: PinnedImageStyle

  init(style: PinnedImageStyle) {
    self.style = style
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override var isOpaque: Bool {
    false
  }

  override func draw(_ dirtyRect: NSRect) {
    let rect = bounds.insetBy(dx: 5, dy: 5)
    let radius = min(CGFloat(24), min(rect.width, rect.height) / 2)
    let fillPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
    shadow.shadowBlurRadius = 16
    shadow.shadowOffset = NSSize(width: 0, height: -4)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    style.background.withAlphaComponent(0.88).setFill()
    fillPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let innerRect = rect.insetBy(dx: 1.2, dy: 1.2)
    let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: radius - 1.2, yRadius: radius - 1.2)
    style.border.withAlphaComponent(0.18).setStroke()
    innerPath.lineWidth = 0.8
    innerPath.stroke()

    guard
      let context = NSGraphicsContext.current?.cgContext,
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
          style.accent.withAlphaComponent(0.78).resolvedCGColor,
          style.border.withAlphaComponent(0.50).resolvedCGColor,
          NSColor.white.withAlphaComponent(0.42).resolvedCGColor,
          style.accent.withAlphaComponent(0.62).resolvedCGColor,
        ] as CFArray,
        locations: [0, 0.36, 0.72, 1]
      )
    else {
      return
    }

    context.saveGState()
    let strokePath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(strokePath)
    context.setLineWidth(1.15)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
      gradient,
      start: CGPoint(x: rect.minX, y: rect.minY),
      end: CGPoint(x: rect.maxX, y: rect.maxY),
      options: []
    )
    context.restoreGState()
  }
}

private extension NSColor {
  var resolvedCGColor: CGColor {
    usingColorSpace(.deviceRGB)?.cgColor ?? cgColor
  }
}
