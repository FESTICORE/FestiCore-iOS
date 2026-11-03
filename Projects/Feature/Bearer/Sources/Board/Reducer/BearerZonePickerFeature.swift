//
//  BearerZonePickerFeature.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture

/// Figma S09 B 존 고르기 시트
@Reducer
public struct BearerZonePickerFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let zones: [BearerZone]
    public let selectedZoneID: String?

    public init(zones: [BearerZone], selectedZoneID: String?) {
      self.zones = zones
      self.selectedZoneID = selectedZoneID
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case zoneTapped(String)
  }

  // MARK: - DelegateAction

  @CasePathable
  public enum DelegateAction: Equatable {
    case picked(String)
  }

  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case .view(.zoneTapped(let zoneID)):
        return .send(.delegate(.picked(zoneID)))

      case .delegate:
        return .none
      }
    }
  }
}
