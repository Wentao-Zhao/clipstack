import AppKit
import Foundation

NSApplication.shared.setActivationPolicy(.prohibited)

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = rootURL
  .appendingPathComponent("Resources", isDirectory: true)
  .appendingPathComponent("AppIcon.iconset", isDirectory: true)

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
  ("icon_16x16.png", 16),
  ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32),
  ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128),
  ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256),
  ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512),
  ("icon_512x512@2x.png", 1024),
]

for size in sizes {
  let image = drawIcon(size: size.pixels)
  let destination = iconsetURL.appendingPathComponent(size.name, isDirectory: false)
  try pngData(from: image)?.write(to: destination, options: .atomic)
}

func drawIcon(size: Int) -> NSImage {
  let canvas = CGFloat(size)
  let image = NSImage(size: NSSize(width: canvas, height: canvas))
  image.lockFocus()

  let backgroundRect = NSRect(
    x: 0,
    y: 0,
    width: canvas,
    height: canvas
  )
  drawRadialGradient(
    in: backgroundRect,
    radius: canvas * 0.225,
    colors: [
      CGColor(red: 0.72, green: 0.65, blue: 0.78, alpha: 1),
      CGColor(red: 0.47, green: 0.56, blue: 0.66, alpha: 1),
      CGColor(red: 0.37, green: 0.44, blue: 0.40, alpha: 1),
    ],
    locations: [0, 0.46, 1],
    center: CGPoint(x: canvas * 0.36, y: canvas * 0.72),
    endRadius: canvas * 0.78
  )

  let outerEchoRect = NSRect(
    x: canvas * 0.225,
    y: canvas * 0.281,
    width: canvas * 0.44,
    height: canvas * 0.55
  )
  drawStroke(
    rect: outerEchoRect,
    radius: canvas * 0.075,
    lineWidth: max(2, canvas * 0.034),
    color: NSColor(red: 1.00, green: 0.97, blue: 0.94, alpha: 0.28)
  )

  let innerEchoRect = NSRect(
    x: canvas * 0.281,
    y: canvas * 0.238,
    width: canvas * 0.44,
    height: canvas * 0.58
  )
  drawStroke(
    rect: innerEchoRect,
    radius: canvas * 0.075,
    lineWidth: max(2, canvas * 0.034),
    color: NSColor(red: 1.00, green: 0.97, blue: 0.94, alpha: 0.38)
  )

  let bodyRect = NSRect(
    x: canvas * 0.34,
    y: canvas * 0.18,
    width: canvas * 0.44,
    height: canvas * 0.62
  )
  let bodyPath = CGPath(
    roundedRect: bodyRect,
    cornerWidth: canvas * 0.075,
    cornerHeight: canvas * 0.075,
    transform: nil
  )

  drawSolidStroke(
    path: bodyPath,
    lineWidth: max(2, canvas * 0.038),
    color: NSColor(red: 1.00, green: 0.97, blue: 0.94, alpha: 0.88)
  )

  let clipRect = NSRect(
    x: canvas * 0.45,
    y: canvas * 0.735,
    width: canvas * 0.213,
    height: canvas * 0.119
  )
  let clip = NSBezierPath(
    roundedRect: clipRect,
    xRadius: canvas * 0.052,
    yRadius: canvas * 0.052
  )
  NSColor(red: 1.00, green: 0.97, blue: 0.94, alpha: 0.76).setFill()
  clip.fill()

  let lines: [(y: CGFloat, color: NSColor)] = [
    (0.59, NSColor(red: 1.00, green: 0.97, blue: 0.94, alpha: 0.76)),
    (0.48, NSColor(red: 1.00, green: 0.97, blue: 0.94, alpha: 0.76)),
    (0.37, NSColor(red: 1.00, green: 0.97, blue: 0.94, alpha: 0.50)),
    (0.26, NSColor(red: 1.00, green: 0.97, blue: 0.94, alpha: 0.50)),
  ]

  for lineConfig in lines {
    lineConfig.color.setStroke()
    let line = NSBezierPath()
    line.move(to: NSPoint(x: canvas * 0.45, y: canvas * lineConfig.y))
    line.line(to: NSPoint(x: canvas * 0.66, y: canvas * lineConfig.y))
    line.lineWidth = max(1, canvas * 0.028)
    line.lineCapStyle = .round
    line.stroke()
  }

  image.unlockFocus()
  return image
}

func drawRadialGradient(
  in rect: NSRect,
  radius: CGFloat,
  colors: [CGColor],
  locations: [CGFloat],
  center: CGPoint,
  endRadius: CGFloat
) {
  guard
    let context = NSGraphicsContext.current?.cgContext,
    let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: colors as CFArray,
      locations: locations
    )
  else {
    return
  }

  context.saveGState()
  let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
  context.addPath(path)
  context.clip()
  context.drawRadialGradient(
    gradient,
    startCenter: center,
    startRadius: 0,
    endCenter: center,
    endRadius: endRadius,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
  )
  context.restoreGState()
}

func drawStroke(
  rect: NSRect,
  radius: CGFloat,
  lineWidth: CGFloat,
  color: NSColor
) {
  let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
  color.setStroke()
  path.lineWidth = lineWidth
  path.lineCapStyle = .round
  path.lineJoinStyle = .round
  path.stroke()
}

func drawGradientStroke(
  path: CGPath,
  lineWidth: CGFloat,
  colors: [CGColor],
  start: NSPoint,
  end: NSPoint
) {
  guard
    let context = NSGraphicsContext.current?.cgContext,
    let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: colors as CFArray,
      locations: nil
    )
  else {
    return
  }

  context.saveGState()
  context.addPath(path)
  context.setLineWidth(lineWidth)
  context.setLineCap(.round)
  context.setLineJoin(.round)
  context.replacePathWithStrokedPath()
  context.clip()
  context.drawLinearGradient(gradient, start: start, end: end, options: [])
  context.restoreGState()
}

func drawSolidStroke(path: CGPath, lineWidth: CGFloat, color: NSColor) {
  guard let context = NSGraphicsContext.current?.cgContext else {
    return
  }

  context.saveGState()
  context.addPath(path)
  context.setLineWidth(lineWidth)
  context.setLineCap(.round)
  context.setLineJoin(.round)
  context.setStrokeColor(color.usingColorSpace(.deviceRGB)?.cgColor ?? color.cgColor)
  context.strokePath()
  context.restoreGState()
}

func pngData(from image: NSImage) -> Data? {
  guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff)
  else {
    return nil
  }

  return bitmap.representation(using: .png, properties: [:])
}
