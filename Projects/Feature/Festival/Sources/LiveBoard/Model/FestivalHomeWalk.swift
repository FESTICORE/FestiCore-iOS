//
//  FestivalHomeWalk.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreLocationInterface

extension FestivalFeature {
  /// 현재 위치에서 귀가 카드의 역·셔틀 정류장까지 걸리는 시간을 구하는 단계
  enum HomeWalkState: Equatable {
    /// 귀가 카드가 아직 보이지 않았다.
    case idle
    /// 권한 확인과 경로 계산 중. 다시 계산하는 동안 직전 결과를 계속 보인다.
    case estimating(
      String,
      last: HomeWalkMinutes?
    )
    /// Apple 지도로 계산한 도보 분. 계산하지 못한 목적지는 nil이다.
    case estimated(
      String,
      HomeWalkMinutes
    )
    /// 위치 권한이 없거나 현재 위치를 잡지 못했다. 서버 값으로 보인다.
    case unavailable(String)

    /// 계산을 멈췄을 때의 상태. 계산 중이었으면 직전 결과로 되돌린다.
    var stopped: HomeWalkState {
      guard case let .estimating(
        id,
        last
      ) = self else { return self }
      guard let last else { return .idle }
      return .estimated(
        id,
        last
      )
    }

    func isEstimating(_ festivalID: String) -> Bool {
      guard case let .estimating(
        id,
        _
      ) = self else { return false }
      return id == festivalID
    }

    /// 이 축제에서 지금 쓸 수 있는 Apple 지도 계산값
    func minutes(for festivalID: String) -> HomeWalkMinutes? {
      switch self {
      case let .estimating(
        id,
        last
      ) where id == festivalID:
        return last
      case let .estimated(
        id,
        minutes
      ) where id == festivalID:
        return minutes
      default:
        return nil
      }
    }
  }

  /// 역·셔틀 정류장까지 걸리는 분
  public struct HomeWalkMinutes: Equatable, Sendable {
    public var station: Int?
    public var shuttleStop: Int?

    public init(
      station: Int? = nil,
      shuttleStop: Int? = nil
    ) {
      self.station = station
      self.shuttleStop = shuttleStop
    }
  }

  /// 도보 시간을 계산하고 Apple 지도로 안내할 목적지
  struct HomeWalkPlaces: Equatable {
    var station: WalkingPlace?
    var shuttleStop: WalkingPlace?

    var isEmpty: Bool {
      return station == nil && shuttleStop == nil
    }
  }
}
