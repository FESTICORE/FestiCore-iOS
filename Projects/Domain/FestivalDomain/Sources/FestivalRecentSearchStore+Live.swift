import Dependencies
import FestivalDomainInterface
import Foundation

extension FestivalRecentSearchStore: DependencyKey {
  private final class DefaultsBox: @unchecked Sendable {
    let value: UserDefaults
    private let lock = NSLock()

    init(_ value: UserDefaults) { self.value = value }

    func withLock<Result>(_ body: (UserDefaults) -> Result) -> Result {
      lock.lock()
      defer { lock.unlock() }
      return body(value)
    }
  }

  private static func key(for userID: String?) -> String {
    guard let userID, !userID.isEmpty else {
      return "FestiCore.festivalRecentSearches.anonymous"
    }
    return "FestiCore.festivalRecentSearches.user.\(userID)"
  }

  private static func searches(in defaults: UserDefaults, for key: String) -> [String] {
    defaults.string(forKey: key)?
      .split(separator: "\n")
      .map(String.init) ?? []
  }

  public static func userDefaults(_ defaults: UserDefaults) -> Self {
    let box = DefaultsBox(defaults)
    return Self(
      load: { userID in
        box.withLock { searches(in: $0, for: key(for: userID)) }
      },
      add: { query, userID in
        box.withLock { defaults in
          let key = key(for: userID)
          let existing = searches(in: defaults, for: key)
          let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !query.isEmpty else { return existing }
          let updated = Array(([query] + existing.filter { $0 != query }).prefix(10))
          defaults.set(updated.joined(separator: "\n"), forKey: key)
          return updated
        }
      },
      remove: { query, userID in
        box.withLock { defaults in
          let key = key(for: userID)
          let updated = searches(in: defaults, for: key).filter { $0 != query }
          defaults.set(updated.joined(separator: "\n"), forKey: key)
          return updated
        }
      },
      clear: { userID in
        box.withLock { $0.removeObject(forKey: key(for: userID)) }
      }
    )
  }

  public static let liveValue = userDefaults(.standard)
}
