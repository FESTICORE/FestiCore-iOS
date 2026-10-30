import Dependencies
import Foundation

public struct FestivalBookedStore: Sendable {
  public var load: @Sendable (_ userID: String) -> Set<String>
  public var save: @Sendable (_ ids: Set<String>, _ userID: String) -> Void
  public var legacyBookmarks: @Sendable () -> Set<String>
  public var resolveLegacyMigrationAction: @Sendable (_ accepted: Bool, _ userID: String) -> Void

  public init(
    load: @escaping @Sendable (_ userID: String) -> Set<String>,
    save: @escaping @Sendable (_ ids: Set<String>, _ userID: String) -> Void,
    legacyBookmarks: @escaping @Sendable () -> Set<String> = { [] },
    resolveLegacyMigration: @escaping @Sendable (_ accepted: Bool, _ userID: String) -> Void = { _, _ in }
  ) {
    self.load = load
    self.save = save
    self.legacyBookmarks = legacyBookmarks
    self.resolveLegacyMigrationAction = resolveLegacyMigration
  }

  public func load(for userID: String) -> Set<String> { load(userID) }
  public func save(_ ids: Set<String>, for userID: String) { save(ids, userID) }

  @discardableResult
  public func setBookmark(_ id: String, booked: Bool, for userID: String) -> Set<String> {
    var ids = load(userID)
    if booked {
      ids.insert(id)
    } else {
      ids.remove(id)
    }
    save(ids, userID)
    return ids
  }

  @discardableResult
  public func toggle(_ id: String, for userID: String) -> Set<String> {
    setBookmark(id, booked: !load(userID).contains(id), for: userID)
  }

  public func resolveLegacyMigration(accepted: Bool, for userID: String) {
    resolveLegacyMigrationAction(accepted, userID)
  }
}

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

  private static func finishAcceptedMigration(for userID: String, defaults: UserDefaults) {
    if defaults.string(forKey: migrationDecisionKey) == "declined" {
      defaults.removeObject(forKey: legacyKey)
      return
    }
    guard defaults.string(forKey: migrationOwnerKey) == userID,
          let legacy = defaults.stringArray(forKey: legacyKey) else { return }
    defaults.set("accepted", forKey: migrationDecisionKey)
    let merged = Set(defaults.stringArray(forKey: accountKey(userID)) ?? []).union(legacy)
    defaults.set(merged.sorted(), forKey: accountKey(userID))
    defaults.removeObject(forKey: legacyKey)
  }

  static func userDefaults(_ defaults: UserDefaults) -> Self {
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
                defaults.string(forKey: migrationOwnerKey) == nil else { return [] }
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
      }
    )
  }

  public static let liveValue = userDefaults(.standard)

  public static let testValue = Self(load: { _ in [] }, save: { _, _ in })
}

public extension DependencyValues {
  var festivalBookedStore: FestivalBookedStore {
    get { self[FestivalBookedStore.self] }
    set { self[FestivalBookedStore.self] = newValue }
  }
}
