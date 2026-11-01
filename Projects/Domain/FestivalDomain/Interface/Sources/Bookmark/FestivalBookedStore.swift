import Dependencies
import Foundation

public struct FestivalBookedStore: Sendable {
  public var load: @Sendable (_ userID: String) -> Set<String>
  public var save: @Sendable (_ ids: Set<String>, _ userID: String) -> Void
  public var legacyBookmarks: @Sendable () -> Set<String>
  public var resolveLegacyMigrationAction: @Sendable (_ accepted: Bool, _ userID: String) -> Void
  public var offlineEligible: @Sendable (_ userID: String) -> Bool
  public var setOfflineEligible: @Sendable (_ userID: String, _ eligible: Bool) -> Void

  public init(
    load: @escaping @Sendable (_ userID: String) -> Set<String>,
    save: @escaping @Sendable (_ ids: Set<String>, _ userID: String) -> Void,
    legacyBookmarks: @escaping @Sendable () -> Set<String> = { [] },
    resolveLegacyMigration: @escaping @Sendable (_ accepted: Bool, _ userID: String) -> Void = {
      _, _ in
    },
    offlineEligible: @escaping @Sendable (_ userID: String) -> Bool = { _ in false },
    setOfflineEligible: @escaping @Sendable (_ userID: String, _ eligible: Bool) -> Void = { _, _ in
    }
  ) {
    self.load = load
    self.save = save
    self.legacyBookmarks = legacyBookmarks
    self.resolveLegacyMigrationAction = resolveLegacyMigration
    self.offlineEligible = offlineEligible
    self.setOfflineEligible = setOfflineEligible
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

extension FestivalBookedStore: TestDependencyKey {
  public static let testValue = Self(load: { _ in [] }, save: { _, _ in })
}

extension DependencyValues {
  public var festivalBookedStore: FestivalBookedStore {
    get { self[FestivalBookedStore.self] }
    set { self[FestivalBookedStore.self] = newValue }
  }
}
