import Foundation
import Testing
@testable import FestiCoreStorage

struct FirstInstallOnboardingFileStoreTests {
  @Test func receiptPersistsWithinInstallAndResetsWithContainer() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = FirstInstallOnboardingFileStore.make(applicationSupportURL: root)
    #expect(try !first.hasCompleted())
    try first.markCompleted()
    #expect(try first.hasCompleted())

    let relaunched = FirstInstallOnboardingFileStore.make(applicationSupportURL: root)
    #expect(try relaunched.hasCompleted())
    try FileManager.default.removeItem(at: root)
    #expect(try !relaunched.hasCompleted())
  }

  @Test func unreadableReceiptDoesNotLookLikeFirstInstall() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let receipt = root.appendingPathComponent("FirstInstallOnboarding/completed")
    try FileManager.default.createDirectory(at: receipt, withIntermediateDirectories: true)
    let store = FirstInstallOnboardingFileStore.make(applicationSupportURL: root)
    #expect(throws: Error.self) { try store.hasCompleted() }
  }

  @Test func existingInstallEvidenceSkipsIntroAndPersistsReceipt() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let suiteName = UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("festival", forKey: "FestiCore.selectedFestivalID")
    let upgraded = FirstInstallOnboardingFileStore.make(
      applicationSupportURL: root, userDefaults: defaults
    )
    #expect(try upgraded.hasCompleted())
    defaults.removeObject(forKey: "FestiCore.selectedFestivalID")
    let relaunched = FirstInstallOnboardingFileStore.make(
      applicationSupportURL: root, userDefaults: defaults
    )
    #expect(try relaunched.hasCompleted())
  }

  @Test func failedReceiptWriteStaysPendingEvenAfterHomeCreatesLegacyKeys() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let suiteName = UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let first = FirstInstallOnboardingFileStore.make(
      applicationSupportURL: root, userDefaults: defaults
    )
    #expect(try !first.hasCompleted())

    let receipt = root.appendingPathComponent("FirstInstallOnboarding/completed")
    try FileManager.default.createDirectory(at: receipt, withIntermediateDirectories: true)
    #expect(throws: Error.self) { try first.markCompleted() }
    try FileManager.default.removeItem(at: receipt)

    defaults.set("festival", forKey: "FestiCore.selectedFestivalID")
    let relaunched = FirstInstallOnboardingFileStore.make(
      applicationSupportURL: root, userDefaults: defaults
    )
    #expect(try !relaunched.hasCompleted())
  }
}
