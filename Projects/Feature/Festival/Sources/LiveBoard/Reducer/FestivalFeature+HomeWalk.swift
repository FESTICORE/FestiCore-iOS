//
//  FestivalFeature+HomeWalk.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FestiCoreLocationInterface
import FestivalDomainInterface
import Foundation

// MARK: - 귀가 카드 도보 시간·Apple 지도 길찾기

extension FestivalFeature {
  /// 위치 권한을 확인하고 현재 위치에서 역·셔틀 정류장까지 Apple 지도로 도보 시간을 계산한다.
  /// 권한이 없거나 현재 위치를 잡지 못하면 서버 값을 쓰도록 알린다.
  func estimateHomeWalk(
    festivalID: String,
    places: HomeWalkPlaces
  ) -> Effect<Action> {
    return .run { send in
      guard await isLocationAuthorized(),
            let origin = try? await locationClient.currentLocation() else {
        await send(.inner(.homeWalkUnavailable(festivalID)))
        return
      }
      async let station = walkingMinutes(
        from: origin,
        to: places.station
      )
      async let shuttleStop = walkingMinutes(
        from: origin,
        to: places.shuttleStop
      )
      let minutes = await HomeWalkMinutes(
        station: station,
        shuttleStop: shuttleStop
      )
      await send(.inner(.homeWalkEstimated(
        festivalID,
        minutes
      )))
    }
    .cancellable(
      id: CancelID.homeWalk,
      cancelInFlight: true
    )
  }

  /// Apple 지도 앱에서 역·정류장까지 도보 길찾기를 연다. 열지 못하면 팩 상세의 가는 길로 대신 보낸다.
  func openHomeDirections(
    festivalID: String,
    place: WalkingPlace
  ) -> Effect<Action> {
    return .run { send in
      guard await !appleMapsClient.openWalkingDirections(to: place) else { return }
      await send(.inner(.homeDirectionsMapsFailed(festivalID)))
    }
  }

  /// 권한을 아직 정하지 않았을 때만 사용 중 권한을 요청한다. 거부·제한이면 다시 묻지 않는다.
  private func isLocationAuthorized() async -> Bool {
    switch await locationClient.authorization() {
    case .authorized:
      return true
    case .notDetermined:
      return await locationClient.requestWhenInUseAuthorization() == .authorized
    case .denied, .restricted:
      return false
    }
  }

  /// 목적지가 없거나 찾지 못하면 nil이라 그 줄은 서버 값을 쓴다.
  private func walkingMinutes(
    from origin: LocationCoordinate,
    to place: WalkingPlace?
  ) async -> Int? {
    guard let place else { return nil }
    let duration = try? await appleMapsClient.walkingDuration(
      from: origin,
      to: place
    )
    return duration?.minutes
  }
}

extension FestivalFeature.State {
  /// 도보 시간을 계산할 역·셔틀 정류장. 이름이 없는 목적지는 빼고, 축제 장소를 검색 기준으로 쓴다.
  var homeWalkPlaces: FestivalFeature.HomeWalkPlaces {
    guard let directions = selectedHomeDirections else { return FestivalFeature.HomeWalkPlaces() }
    let venue = directions.venueLocation.map(Self.locationCoordinate)
    return FestivalFeature.HomeWalkPlaces(
      station: Self.walkingPlace(
        named: directions.transit?.stationName,
        section: directions.transit,
        searchCenter: venue
      ),
      shuttleStop: Self.walkingPlace(
        named: directions.shuttleStopName,
        section: directions.shuttle,
        searchCenter: venue
      )
    )
  }

  /// 귀가 카드에 보일 도보 분. Apple 지도 계산값을 먼저 쓰고, 계산하지 못한 역은 서버 값으로 대신한다.
  /// 셔틀 정류장은 서버 값이 없어 계산하지 못하면 비워 둔다.
  var homeWalkMinutes: FestivalFeature.HomeWalkMinutes {
    guard let festivalID = selectedFestivalID,
          let directions = homeDetails.directions(for: festivalID) else { return FestivalFeature.HomeWalkMinutes() }
    let estimated = homeWalk.minutes(for: festivalID)
    return FestivalFeature.HomeWalkMinutes(
      station: estimated?.station ?? directions.transit?.walkMinutes,
      shuttleStop: estimated?.shuttleStop
    )
  }

  /// "가는 길"이 Apple 지도로 안내할 목적지. 카드가 안내하는 출발편의 역·정류장을 먼저 고른다.
  func homeDirectionsPlace(now: Date) -> WalkingPlace? {
    let places = homeWalkPlaces
    let departure = selectedHomeDirections.flatMap { directions in
      return FestivalHomeDeparture(
        directions: directions,
        walkMinutes: homeWalkMinutes,
        now: now
      )
    }
    switch departure?.kind {
    case .shuttle:
      return places.shuttleStop ?? places.station
    case .train, nil:
      return places.station ?? places.shuttleStop
    }
  }

  private var selectedHomeDirections: FestivalPackDetail.Directions? {
    return selectedFestivalID.flatMap { homeDetails.directions(for: $0) }
  }

  private static func walkingPlace(
    named name: String?,
    section: FestivalPackDetail.Section?,
    searchCenter: LocationCoordinate?
  ) -> WalkingPlace? {
    guard let name else { return nil }
    return WalkingPlace(
      name: name,
      coordinate: section?.location.map(locationCoordinate),
      searchCenter: searchCenter
    )
  }

  private static func locationCoordinate(_ coordinate: FestivalPackDetail.Coordinate) -> LocationCoordinate {
    return LocationCoordinate(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude
    )
  }
}

extension FestivalPackDetail.Directions {
  /// 셔틀 정류장 이름. 정류장 이름이 없던 예전 팩은 역 이름 칸을 쓴다.
  var shuttleStopName: String? {
    return shuttle?.stopName ?? shuttle?.stationName
  }
}
