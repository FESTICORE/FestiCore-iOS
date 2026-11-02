//
//  FestivalPackLocalStore+Live.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestivalDomainInterface
import Foundation

extension FestivalPackLocalStore: DependencyKey {
  private final class DefaultsBox: @unchecked Sendable {
    let value: UserDefaults

    init(_ value: UserDefaults) { self.value = value }
  }

  private static let autoDownloadKey = "FestiCore.pack.autoDownloadOnWiFi"

  private static func checklistKey(_ festivalID: String) -> String {
    "FestiCore.pack.checklist.\(festivalID)"
  }

  public static func userDefaults(_ defaults: UserDefaults) -> Self {
    let box = DefaultsBox(defaults)
    return Self(
      loadChecklist: { festivalID in
        guard let data = box.value.data(forKey: checklistKey(festivalID)),
              let checklist = try? JSONDecoder().decode(FestivalChecklist.self, from: data) else {
          return FestivalChecklist()
        }
        return checklist
      },
      saveChecklist: { checklist, festivalID in
        guard let data = try? JSONEncoder().encode(checklist) else { return }
        box.value.set(data, forKey: checklistKey(festivalID))
      },
      autoDownloadOnWiFi: {
        // 처음에는 켜 둔다.
        box.value.object(forKey: autoDownloadKey) as? Bool ?? true
      },
      setAutoDownloadOnWiFi: { isOn in
        box.value.set(isOn, forKey: autoDownloadKey)
      }
    )
  }

  public static let liveValue = userDefaults(.standard)
}
