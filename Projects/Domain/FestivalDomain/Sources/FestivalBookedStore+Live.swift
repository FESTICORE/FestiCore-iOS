import Dependencies
import FestivalDomainInterface
import Foundation

extension FestivalBookedStore: DependencyKey {
  // UserDefaults synchronizes access across threads; the box keeps its non-Sendable
  // Foundation reference out of the dependency's Sendable closures.
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

  private static let legacyKey = "FestiCore.bookedFestivalIDs"
  private static let migrationDecisionKey = "FestiCore.bookedFestivalIDs.migrationDecision"
  private static let migrationOwnerKey = "FestiCore.bookedFestivalIDs.migrationOwner"

  private static func accountKey(_ userID: String) -> String {
    "FestiCore.bookedFestivalIDs.user.\(userID)"
  }

  private static func eligibilityKey(_ userID: String) -> String {
    "FestiCore.bookedFestivalIDs.eligible.\(userID)"
  }

  private static func finishAcceptedMigration(for userID: String, defaults: UserDefaults) {
    if defaults.string(forKey: migrationDecisionKey) == "declined" {
      defaults.removeObject(forKey: legacyKey)
      return
    }
    guard defaults.string(forKey: migrationOwnerKey) == userID,
      let legacy = defaults.stringArray(forKey: legacyKey)
    else { return }
    defaults.set("accepted", forKey: migrationDecisionKey)
    let merged = Set(defaults.stringArray(forKey: accountKey(userID)) ?? []).union(legacy)
    defaults.set(merged.sorted(), forKey: accountKey(userID))
    defaults.removeObject(forKey: legacyKey)
  }

  public static func userDefaults(_ defaults: UserDefaults) -> Self {
    let box = DefaultsBox(defaults)
    return Self(
      load: { userID in
        box.withLock { defaults in
          guard !userID.isEmpty else { return [] }
          finishAcceptedMigration(for: userID, defaults: defaults)
          return Set(defaults.stringArray(forKey: accountKey(userID)) ?? [])
        }
      },
      save: { ids, userID in
        box.withLock { defaults in
          guard !userID.isEmpty else { return }
          finishAcceptedMigration(for: userID, defaults: defaults)
          defaults.set(ids.sorted(), forKey: accountKey(userID))
        }
      },
      legacyBookmarks: {
        box.withLock { defaults in
          guard defaults.string(forKey: migrationDecisionKey) == nil,
            defaults.string(forKey: migrationOwnerKey) == nil
          else { return [] }
          return Set(defaults.stringArray(forKey: legacyKey) ?? [])
        }
      },
      resolveLegacyMigration: { accepted, userID in
        box.withLock { defaults in
          guard !userID.isEmpty else { return }
          if defaults.string(forKey: migrationDecisionKey) != nil {
            finishAcceptedMigration(for: userID, defaults: defaults)
            return
          }
          if let owner = defaults.string(forKey: migrationOwnerKey), owner != userID { return }
          if accepted { defaults.set(userID, forKey: migrationOwnerKey) }
          defaults.set(accepted ? "accepted" : "declined", forKey: migrationDecisionKey)
          if accepted {
            finishAcceptedMigration(for: userID, defaults: defaults)
          } else {
            defaults.removeObject(forKey: legacyKey)
          }
        }
      },
      offlineEligible: { userID in
        box.withLock { defaults in
          !userID.isEmpty && defaults.bool(forKey: eligibilityKey(userID))
        }
      },
      setOfflineEligible: { userID, eligible in
        box.withLock { defaults in
          guard !userID.isEmpty else { return }
          defaults.set(eligible, forKey: eligibilityKey(userID))
        }
      }
    )
  }

  public static let liveValue = userDefaults(.standard)
}
