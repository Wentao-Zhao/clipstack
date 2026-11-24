import Foundation

/// Display-only interpretation of a preview. Stored clipboard data is never transformed.
public struct ClipboardContentPresentation {
  public enum Kind: Equatable {
    case image, text, link, code
  }

  public let kind: Kind
  public let title: String
  public let body: String
  public let badge: String

  public init(item: ClipboardHistoryItem) {
    guard item.kind == .text else {
      kind = .image
      title = "截图"
      body = ""
      badge = "图片"
      return
    }

    let text = item.preview.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.contains(where: { $0.isWhitespace }),
       let url = URLComponents(string: text),
       let scheme = url.scheme?.lowercased(),
       ["http", "https"].contains(scheme),
       let host = url.host, !host.isEmpty {
      kind = .link
      title = host + (url.port.map { ":\($0)" } ?? "")
      body = (url.percentEncodedPath.isEmpty ? "/" : url.percentEncodedPath)
        + (url.percentEncodedQuery.map { "?\($0)" } ?? "")
        + (url.percentEncodedFragment.map { "#\($0)" } ?? "")
      badge = scheme.uppercased()
      return
    }

    if let language = Self.codeLanguage(text) {
      kind = .code
      title = language
      body = item.preview
      badge = language
      return
    }

    kind = .text
    let lines = text.components(separatedBy: .newlines)
    title = lines.first.flatMap { $0.isEmpty ? nil : $0 } ?? "空文本"
    body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    badge = "文本"
  }

  private static func codeLanguage(_ text: String) -> String? {
    if let first = text.first, first == "{" || first == "[",
       let data = text.data(using: .utf8),
       (try? JSONSerialization.jsonObject(with: data)) != nil {
      return "JSON"
    }
    if text.range(
      of: #"(?is)^(SELECT\s+.+?\s+FROM\s+|INSERT\s+INTO\s+|UPDATE\s+\S+\s+SET\s+|DELETE\s+FROM\s+|CREATE\s+TABLE\s+|ALTER\s+TABLE\s+)"#,
      options: .regularExpression
    ) != nil {
      return "SQL"
    }
    if text.range(
      of: #"(?m)^\s*(func\s+\w+\s*\(|(?:async\s+)?function\s+\w+\s*\(|def\s+\w+\s*\(|(?:public\s+|private\s+)?(?:struct|class|enum)\s+\w+[^\n]*\{|(?:const|let|var)\s+\w+\s*=)"#,
      options: .regularExpression
    ) != nil {
      return "代码"
    }
    return nil
  }
}
