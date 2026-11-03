import Dependencies
import FestiCoreStorageInterface
import Foundation

public enum FirstInstallOnboardingFileStore {
  public static func make(
    applicationSupportURL: URL? = nil,
    userDefaults: UserDefaults = .standard
  ) -> FirstInstallOnboardingStore {
    let baseURL = applicationSupportURL ?? FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0]
    let directory = baseURL.appendingPathComponent("FirstInstallOnboarding", isDirectory: true)
    let receipt = directory.appendingPathComponent("completed", isDirectory: false)
    let pending = directory.appendingPathComponent("pending", isDirectory: false)
    // These keys are written only after a person uses the older app. Fresh installs
    // have none of them; Keychain survives reinstall and is intentionally excluded.
    let hasLegacyData = userDefaults.dictionaryRepresentation().keys.contains { key in
        key == "FestiCore.selectedFestivalID" ||
          key.hasPrefix("FestiCore.bookedFestivalIDs") ||
          key.hasPrefix("FestiCore.festivalRecentSearches")
      }
    let prepareDirectory: @Sendable () throws -> Void = {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var mutableDirectory = directory
      try mutableDirectory.setResourceValues(values)
    }
    let persist: @Sendable () throws -> Void = {
      try prepareDirectory()
      try Data([1]).write(to: receipt, options: .atomic)
      try? FileManager.default.removeItem(at: pending)
    }

    return FirstInstallOnboardingStore(
      hasCompleted: {
        do {
          _ = try Data(contentsOf: receipt)
          return true
        } catch let error as NSError
          where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
          if FileManager.default.fileExists(atPath: pending.path) {
            return false
          }
          if hasLegacyData {
            try persist()
            return true
          }
          try prepareDirectory()
          try Data([1]).write(to: pending, options: .atomic)
          return false
        }
      },
      markCompleted: persist
    )
  }
}

extension FirstInstallOnboardingStoreDependency: DependencyKey {
  public static var liveValue: FirstInstallOnboardingStore {
    FirstInstallOnboardingFileStore.make()
  }
}
