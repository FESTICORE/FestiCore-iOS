//
//  SessionRevocationJournal.swift
//  FestiCoreAuth
//
//  Created by FestiCore on 11/01/26.
//

import Foundation

/// Keychain 삭제가 실패해도 다음 실행에서 이전 토큰을 복원하지 않도록 남기는 기록.
final class SessionRevocationJournal: Sendable {
  enum State: String {
    case signOutRequested
    case signOutConfirmed
    case withdrawalRequested
    case withdrawalAuthorizationRejected
    case withdrawalCompleted
  }

  enum Status {
    case absent
    case pending(State)
    case unreadable
  }

  let url: URL

  init(url: URL) { self.url = url }

  var status: Status {
    do {
      let data = try Data(contentsOf: url)
      guard let raw = String(data: data, encoding: .utf8),
            let state = State(rawValue: raw) else { return .unreadable }
      return .pending(state)
    } catch {
      if (error as NSError).code == NSFileReadNoSuchFileError,
         (error as NSError).domain == NSCocoaErrorDomain { return .absent }
      return .unreadable
    }
  }

  func record(_ state: State) -> Bool {
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try Data(state.rawValue.utf8).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
      guard case let .pending(saved) = status, saved == state else { return false }
      return true
    } catch { return false }
  }

  func clear() -> Bool {
    switch status {
    case .absent: return true
    case .unreadable: return false
    case .pending:
      do {
        try FileManager.default.removeItem(at: url)
        if case .absent = status { return true }
        return false
      } catch { return false }
    }
  }
}
