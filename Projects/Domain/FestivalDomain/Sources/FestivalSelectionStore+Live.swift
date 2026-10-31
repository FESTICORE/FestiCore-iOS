import Dependencies
import FestivalDomainInterface
import Foundation

extension FestivalSelectionStore: DependencyKey {
  private static let key = "FestiCore.selectedFestivalID"

  public static let liveValue = Self(
    load: { UserDefaults.standard.string(forKey: key) },
    save: { UserDefaults.standard.set($0, forKey: key) }
  )
}
