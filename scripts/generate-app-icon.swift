import AppKit
import Foundation

// A2: porcelain tile, layered blue cards, a white clamp and two content strokes.
// Native paths keep the selected design clean at every macOS icon size.
let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
  ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for size in sizes {
  let data = try drawIcon(pixels: size.pixels)
  try data.write(to: iconsetURL.appendingPathComponent(size.name), options: .atomic)
  if size.pixels == 1024 {
    try data.write(to: resourcesURL.appendingPathComponent("AppIcon.png"), options: .atomic)
  }
}

func drawIcon(pixels: Int) throws -> Data {
  guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
  ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    throw IconError.renderFailed
  }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphics
  defer { NSGraphicsContext.restoreGraphicsState() }
  let context = graphics.cgContext
  context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
  let scale = CGFloat(pixels) / 1024
  context.scaleBy(x: scale, y: scale)
  context.setShouldAntialias(true)

  let tile = CGPath(roundedRect: CGRect(x: 84, y: 80, width: 856, height: 856),
                    cornerWidth: 190, cornerHeight: 190, transform: nil)
  shadowedFill(tile, color: rgb(0.96, 0.97, 0.99), blur: 12, offset: -5, opacity: 0.12, in: context)
  gradient(tile, colors: [rgb(0.995, 0.996, 1), rgb(0.955, 0.960, 0.980)],
           start: CGPoint(x: 380, y: 920), end: CGPoint(x: 670, y: 90), in: context)
  context.addPath(tile)
  context.setStrokeColor(rgb(0.76, 0.79, 0.84, 0.24))
  context.setLineWidth(1.5)
  context.strokePath()

  // A tilted rear sheet distinguishes saved history from the current item.
  context.saveGState()
  context.translateBy(x: 456, y: 552)
  context.rotate(by: 7 * .pi / 180)
  let rear = CGPath(roundedRect: CGRect(x: -224, y: -252, width: 448, height: 528),
                    cornerWidth: 64, cornerHeight: 64, transform: nil)
  shadowedFill(rear, color: rgb(0.57, 0.80, 0.99), blur: 16, offset: -8, opacity: 0.12, in: context)
  gradient(rear, colors: [rgb(0.70, 0.88, 1), rgb(0.45, 0.72, 0.97)],
           start: CGPoint(x: -180, y: 270), end: CGPoint(x: 150, y: -250), in: context)
  context.restoreGState()

  let front = CGPath(roundedRect: CGRect(x: 304, y: 204, width: 452, height: 528),
                     cornerWidth: 70, cornerHeight: 70, transform: nil)
  shadowedFill(front, color: rgb(0.02, 0.32, 0.89), blur: 24, offset: -16, opacity: 0.24, in: context)
  gradient(front, colors: [rgb(0.02, 0.47, 1), rgb(0.015, 0.32, 0.94), rgb(0.025, 0.22, 0.77)],
           start: CGPoint(x: 390, y: 732), end: CGPoint(x: 650, y: 204), in: context)
  context.saveGState()
  context.addPath(front)
  context.clip()
  context.addPath(front)
  context.setStrokeColor(rgb(0.65, 0.85, 1, 0.4))
  context.setLineWidth(2)
  context.strokePath()
  context.restoreGState()

  // A continuous clamp silhouette with a hole, avoiding overlapping seams.
  let clamp = CGMutablePath()
  clamp.move(to: CGPoint(x: 440, y: 621))
  clamp.addLine(to: CGPoint(x: 624, y: 621))
  clamp.addCurve(to: CGPoint(x: 663, y: 660), control1: CGPoint(x: 646, y: 621), control2: CGPoint(x: 663, y: 638))
  clamp.addCurve(to: CGPoint(x: 624, y: 699), control1: CGPoint(x: 663, y: 682), control2: CGPoint(x: 646, y: 699))
  clamp.addLine(to: CGPoint(x: 600, y: 699))
  clamp.addQuadCurve(to: CGPoint(x: 591, y: 708), control: CGPoint(x: 591, y: 699))
  clamp.addCurve(to: CGPoint(x: 532, y: 767), control1: CGPoint(x: 591, y: 741), control2: CGPoint(x: 565, y: 767))
  clamp.addCurve(to: CGPoint(x: 473, y: 708), control1: CGPoint(x: 499, y: 767), control2: CGPoint(x: 473, y: 741))
  clamp.addQuadCurve(to: CGPoint(x: 464, y: 699), control: CGPoint(x: 473, y: 699))
  clamp.addLine(to: CGPoint(x: 440, y: 699))
  clamp.addCurve(to: CGPoint(x: 401, y: 660), control1: CGPoint(x: 418, y: 699), control2: CGPoint(x: 401, y: 682))
  clamp.addCurve(to: CGPoint(x: 440, y: 621), control1: CGPoint(x: 401, y: 638), control2: CGPoint(x: 418, y: 621))
  clamp.closeSubpath()
  clamp.addEllipse(in: CGRect(x: 508, y: 684, width: 48, height: 48))
  shadowedFill(clamp, color: rgb(0.98, 0.985, 1), blur: 10, offset: -7, opacity: 0.18,
               rule: .evenOdd, in: context)
  gradient(clamp, colors: [rgb(1, 1, 1), rgb(0.95, 0.965, 0.995)],
           start: CGPoint(x: 500, y: 767), end: CGPoint(x: 550, y: 621), rule: .evenOdd, in: context)

  for rect in [CGRect(x: 370, y: 412, width: 324, height: 43),
               CGRect(x: 370, y: 332, width: 249, height: 43)] {
    let line = CGPath(roundedRect: rect, cornerWidth: 21.5, cornerHeight: 21.5, transform: nil)
    gradient(line, colors: [rgb(1, 1, 1), rgb(0.95, 0.965, 1)],
             start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), in: context)
  }
  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw IconError.renderFailed
  }
  return data
}

func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

func gradient(_ path: CGPath, colors: [CGColor], start: CGPoint, end: CGPoint,
              rule: CGPathFillRule = .winding, in context: CGContext) {
  context.saveGState()
  defer { context.restoreGState() }
  context.addPath(path)
  context.clip(using: rule)
  let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                            colors: colors as CFArray, locations: nil)!
  context.drawLinearGradient(gradient, start: start, end: end,
                             options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func shadowedFill(_ path: CGPath, color: CGColor, blur: CGFloat, offset: CGFloat, opacity: CGFloat,
                  rule: CGPathFillRule = .winding, in context: CGContext) {
  context.saveGState()
  defer { context.restoreGState() }
  context.setShadow(offset: CGSize(width: 0, height: offset), blur: blur, color: rgb(0.06, 0.11, 0.25, opacity))
  context.addPath(path)
  context.setFillColor(color)
  context.drawPath(using: rule == .evenOdd ? .eoFill : .fill)
}

enum IconError: Error {
  case renderFailed
}
