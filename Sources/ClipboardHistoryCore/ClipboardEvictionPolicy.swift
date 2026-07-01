import Foundation

public struct ClipboardPruneResult<Entry> {
  public var remaining: [Entry]
  public var removed: [Entry]

  public init(remaining: [Entry], removed: [Entry]) {
    self.remaining = remaining
    self.removed = removed
  }
}

public struct ClipboardCacheEntry: Equatable {
  public var id: String
  public var byteSize: Int
  public var lastUsedAt: Date

  public init(id: String, byteSize: Int, lastUsedAt: Date) {
    self.id = id
    self.byteSize = byteSize
    self.lastUsedAt = lastUsedAt
  }
}

public enum ClipboardEvictionPolicy {
  public static func pruneExpired(
    _ items: [ClipboardHistoryItem],
    now: Date,
    config: ClipboardConfiguration
  ) -> ClipboardPruneResult<ClipboardHistoryItem> {
    let partitioned = partition(items) { item in
      now.timeIntervalSince(item.createdAt) <= config.retentionDuration
    }
    return ClipboardPruneResult(remaining: partitioned.kept, removed: partitioned.removed)
  }

  public static func pruneCounts(
    _ items: [ClipboardHistoryItem],
    config: ClipboardConfiguration
  ) -> ClipboardPruneResult<ClipboardHistoryItem> {
    var remaining: [ClipboardHistoryItem] = []
    var removed: [ClipboardHistoryItem] = []

    for kind in ClipboardItemKind.allCases {
      let limit = kind == .text ? config.maxTextItems : config.maxImageItems
      let matching = items
        .filter { $0.kind == kind }
        .sorted { lhs, rhs in
          if lhs.lastUsedAt == rhs.lastUsedAt {
            return lhs.createdAt > rhs.createdAt
          }
          return lhs.lastUsedAt > rhs.lastUsedAt
        }

      remaining.append(contentsOf: matching.prefix(limit))
      removed.append(contentsOf: matching.dropFirst(limit))
    }

    return ClipboardPruneResult(remaining: remaining, removed: removed)
  }

  public static func pruneMemoryCache(
    _ entries: [ClipboardCacheEntry],
    config: ClipboardConfiguration
  ) -> ClipboardPruneResult<ClipboardCacheEntry> {
    guard config.memoryBudgetBytes > 0 else {
      return ClipboardPruneResult(remaining: [], removed: entries)
    }

    let triggerBytes = Int(Double(config.memoryBudgetBytes) * config.memoryCleanupTriggerRatio)
    let targetBytes = Int(Double(config.memoryBudgetBytes) * config.memoryCleanupTargetRatio)
    let totalBytes = entries.reduce(0) { total, entry in total + entry.byteSize }

    guard totalBytes > triggerBytes else {
      return ClipboardPruneResult(remaining: entries, removed: [])
    }

    var remaining = entries.sorted { lhs, rhs in
      if lhs.lastUsedAt == rhs.lastUsedAt {
        return lhs.id < rhs.id
      }
      return lhs.lastUsedAt < rhs.lastUsedAt
    }
    var removed: [ClipboardCacheEntry] = []
    var currentBytes = totalBytes

    while currentBytes > targetBytes, let entry = remaining.first {
      removed.append(entry)
      remaining.removeFirst()
      currentBytes -= entry.byteSize
    }

    return ClipboardPruneResult(
      remaining: remaining.sorted { lhs, rhs in lhs.lastUsedAt > rhs.lastUsedAt },
      removed: removed
    )
  }

  private static func partition<Entry>(
    _ entries: [Entry],
    keep: (Entry) -> Bool
  ) -> (kept: [Entry], removed: [Entry]) {
    var kept: [Entry] = []
    var removed: [Entry] = []

    for entry in entries {
      if keep(entry) {
        kept.append(entry)
      } else {
        removed.append(entry)
      }
    }

    return (kept, removed)
  }
}

