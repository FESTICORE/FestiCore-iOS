import Dependencies
import FestivalDomainInterface
import Foundation

extension FestivalGuideVisibilityStore: DependencyKey {
  private final class DefaultsBox: @unchecked Sendable {
    let defaults: UserDefaults
    let lock = NSLock()

    init(_ defaults: UserDefaults) { self.defaults = defaults }

    func withLock<Result>(_ body: (UserDefaults) -> Result) -> Result {
      lock.lock()
      defer { lock.unlock() }
      return body(defaults)
    }
  }

  private static let key = "FestiCore.hiddenFollowedFlagGuides"

  public static func userDefaults(_ defaults: UserDefaults) -> Self {
    let box = DefaultsBox(defaults)
    return Self(
      isHidden: { festivalID in
        box.withLock { $0.stringArray(forKey: key)?.contains(festivalID) == true }
      },
      hide: { festivalID in
        guard !festivalID.isEmpty else { return }
        box.withLock { defaults in
          var hidden = Set(defaults.stringArray(forKey: key) ?? [])
          hidden.insert(festivalID)
          defaults.set(hidden.sorted(), forKey: key)
        }
      }
    )
  }

  public static let liveValue = userDefaults(.standard)
}
