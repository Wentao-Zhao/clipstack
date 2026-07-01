public enum ClipboardCapturePolicy {
  public static let textPreviewCharacterLimit = 500

  public static func shouldCaptureText(
    byteCount: Int,
    config: ClipboardConfiguration
  ) -> Bool {
    byteCount > 0 && byteCount <= config.maxTextBytes
  }

  public static func shouldCaptureImage(
    byteCount: Int,
    config: ClipboardConfiguration
  ) -> Bool {
    byteCount > 0 && byteCount <= config.maxImageBytes
  }

  public static func preview(for text: String) -> String {
    String(text.prefix(textPreviewCharacterLimit))
  }
}

