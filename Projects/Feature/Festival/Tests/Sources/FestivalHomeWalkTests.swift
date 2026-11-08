//
//  FestivalHomeWalkTests.swift
//  FestivalTests
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FestiCoreLocationInterface
import FestiCoreUtility
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

/// 귀가 카드의 위치 권한·Apple 지도 도보 시간·"가는 길" 연결
@MainActor
struct FestivalHomeWalkTests {
  // MARK: - 권한 상태별 도보 시간 계산

  @Test("위치 권한이 있으면 현재 위치에서 역·셔틀 정류장까지 도보 분을 계산한다")
  func estimatesWalkWhenAuthorized() async {
    let store = TestStore(initialState: homeState()) {
      FestivalFeature()
    } withDependencies: {
      $0.locationClient = MockLocationClient(
        authorization: { .authorized },
        currentLocation: { origin }
      )
      $0.appleMapsClient = routeClient()
    }

    await store.send(.view(.homeRideAppeared)) {
      $0.homeWalk = .estimating(
        festivalID,
        last: nil
      )
    }
    await store.receive(\.async.estimateHomeWalk)
    await store.receive(\.inner.homeWalkEstimated) {
      $0.homeWalk = .estimated(
        festivalID,
        .init(
          station: 8,
          shuttleStop: 3
        )
      )
    }
  }

  @Test("권한을 아직 정하지 않았으면 사용 중 권한을 요청하고 허용되면 계산한다")
  func requestsAuthorizationWhenNotDetermined() async {
    let requests = LockIsolated(0)
    let store = TestStore(initialState: homeState()) {
      FestivalFeature()
    } withDependencies: {
      $0.locationClient = MockLocationClient(
        authorization: { .notDetermined },
        requestWhenInUseAuthorization: {
          requests.withValue { $0 += 1 }
          return .authorized
        },
        currentLocation: { origin }
      )
      $0.appleMapsClient = routeClient()
    }

    await store.send(.view(.homeRideAppeared)) {
      $0.homeWalk = .estimating(
        festivalID,
        last: nil
      )
    }
    await store.receive(\.async.estimateHomeWalk)
    await store.receive(\.inner.homeWalkEstimated) {
      $0.homeWalk = .estimated(
        festivalID,
        .init(
          station: 8,
          shuttleStop: 3
        )
      )
    }
    #expect(requests.value == 1)
  }

  @Test("권한 요청을 거부하면 위치를 읽지 않고 서버 값으로 둔다")
  func fallsBackWhenRequestDenied() async {
    // 현재 위치·지도 대역을 넘기지 않아 호출되면 테스트 이슈가 된다.
    let store = TestStore(initialState: homeState()) {
      FestivalFeature()
    } withDependencies: {
      $0.locationClient = MockLocationClient(
        authorization: { .notDetermined },
        requestWhenInUseAuthorization: { .denied }
      )
    }

    await store.send(.view(.homeRideAppeared)) {
      $0.homeWalk = .estimating(
        festivalID,
        last: nil
      )
    }
    await store.receive(\.async.estimateHomeWalk)
    await store.receive(\.inner.homeWalkUnavailable) {
      $0.homeWalk = .unavailable(festivalID)
    }
  }

  @Test(
    "거부·제한 상태에서는 권한을 다시 묻지 않고 서버 값으로 둔다",
    arguments: [
      LocationAuthorization.denied,
      .restricted,
    ]
  )
  func doesNotAskAgainWhenRefused(authorization: LocationAuthorization) async {
    // 권한 요청 대역을 넘기지 않아 다시 물으면 테스트 이슈가 된다.
    let store = TestStore(initialState: homeState()) {
      FestivalFeature()
    } withDependencies: {
      $0.locationClient = MockLocationClient(authorization: { authorization })
    }

    await store.send(.view(.homeRideAppeared)) {
      $0.homeWalk = .estimating(
        festivalID,
        last: nil
      )
    }
    await store.receive(\.async.estimateHomeWalk)
    await store.receive(\.inner.homeWalkUnavailable) {
      $0.homeWalk = .unavailable(festivalID)
    }
  }

  @Test("현재 위치를 잡지 못하면 서버 값으로 둔다")
  func fallsBackWhenLocationFails() async {
    let store = TestStore(initialState: homeState()) {
      FestivalFeature()
    } withDependencies: {
      $0.locationClient = MockLocationClient(
        authorization: { .authorized },
        currentLocation: { throw LocationClientError.locationUnavailable }
      )
    }

    await store.send(.view(.homeRideAppeared)) {
      $0.homeWalk = .estimating(
        festivalID,
        last: nil
      )
    }
    await store.receive(\.async.estimateHomeWalk)
    await store.receive(\.inner.homeWalkUnavailable) {
      $0.homeWalk = .unavailable(festivalID)
    }
  }

  @Test("역을 찾지 못해도 정류장 도보 분은 남기고 역은 서버 값으로 보인다")
  func keepsPartialEstimate() async {
    let store = TestStore(initialState: homeState()) {
      FestivalFeature()
    } withDependencies: {
      $0.locationClient = MockLocationClient(
        authorization: { .authorized },
        currentLocation: { origin }
      )
      $0.appleMapsClient = MockAppleMapsClient(walkingDuration: { _, place in
        guard place.name == shuttleStopName else { throw LocationClientError.placeNotFound }
        return WalkingDuration(seconds: 150)
      })
    }

    await store.send(.view(.homeRideAppeared)) {
      $0.homeWalk = .estimating(
        festivalID,
        last: nil
      )
    }
    await store.receive(\.async.estimateHomeWalk)
    await store.receive(\.inner.homeWalkEstimated) {
      $0.homeWalk = .estimated(
        festivalID,
        .init(
          station: nil,
          shuttleStop: 3
        )
      )
    }
    #expect(store.state.homeWalkMinutes == .init(
      station: 12,
      shuttleStop: 3
    ))
  }

  @Test("서버가 준 역 좌표가 있으면 그 좌표를 목적지로 넘기고 이름 검색 기준은 축제 장소다")
  func passesServerCoordinateAndVenue() async {
    let station = FestivalPackDetail.Coordinate(
      latitude: 37.3836,
      longitude: 127.1268
    )
    let places = homeState(directions: directions(stationLocation: station)).homeWalkPlaces

    #expect(places.station == WalkingPlace(
      name: stationName,
      coordinate: LocationCoordinate(
        latitude: 37.3836,
        longitude: 127.1268
      ),
      searchCenter: venueCoordinate
    ))
    #expect(places.shuttleStop == WalkingPlace(
      name: shuttleStopName,
      coordinate: nil,
      searchCenter: venueCoordinate
    ))
  }

  @Test("계산 중에 카드가 다시 보여도 새로 계산하지 않는다")
  func ignoresAppearWhileEstimating() async {
    var state = homeState()
    state.homeWalk = .estimating(
      festivalID,
      last: nil
    )
    let store = TestStore(initialState: state) { FestivalFeature() }

    await store.send(.view(.homeRideAppeared))
  }

  @Test("다시 계산하는 동안에는 직전 도보 분을 계속 보인다")
  func keepsLastEstimateWhileRefreshing() async {
    var state = homeState()
    state.homeWalk = .estimated(
      festivalID,
      .init(
        station: 5,
        shuttleStop: 2
      )
    )
    let store = TestStore(initialState: state) {
      FestivalFeature()
    } withDependencies: {
      $0.locationClient = MockLocationClient(authorization: { .denied })
    }

    await store.send(.view(.homeRideAppeared)) {
      $0.homeWalk = .estimating(
        festivalID,
        last: .init(
          station: 5,
          shuttleStop: 2
        )
      )
    }
    #expect(store.state.homeWalkMinutes == .init(
      station: 5,
      shuttleStop: 2
    ))
    await store.receive(\.async.estimateHomeWalk)
    await store.receive(\.inner.homeWalkUnavailable) {
      $0.homeWalk = .unavailable(festivalID)
    }
  }

  @Test("라이브 보드를 떠나면 계산을 멈추고 직전 결과로 되돌려 다시 보일 때 새로 계산한다")
  func stopsEstimateWhenLiveBoardDisappears() async {
    var state = homeState()
    state.homeWalk = .estimating(
      festivalID,
      last: .init(
        station: 5,
        shuttleStop: 2
      )
    )
    let store = TestStore(initialState: state) { FestivalFeature() }

    await store.send(.view(.liveBoardOnDisappear)) {
      $0.homeWalk = .estimated(
        festivalID,
        .init(
          station: 5,
          shuttleStop: 2
        )
      )
    }
  }

  @Test("직전 결과 없이 계산하다 떠나면 처음 상태로 둔다")
  func resetsEstimateWithoutLastWhenLiveBoardDisappears() async {
    var state = homeState()
    state.homeWalk = .estimating(
      festivalID,
      last: nil
    )
    let store = TestStore(initialState: state) { FestivalFeature() }

    await store.send(.view(.liveBoardOnDisappear)) {
      $0.homeWalk = .idle
    }
  }

  @Test("역·정류장 이름이 없으면 위치 권한을 묻지 않는다")
  func skipsWithoutPlaces() async {
    let store = TestStore(initialState: homeState(directions: .init(lastTrainAt: "23:52"))) {
      FestivalFeature()
    }

    await store.send(.view(.homeRideAppeared))
  }

  @Test("이전 축제의 도보 계산 결과는 현재 카드를 바꾸지 않는다")
  func ignoresStaleEstimate() async {
    let store = TestStore(initialState: homeState()) { FestivalFeature() }

    await store.send(.inner(.homeWalkEstimated(
      "old",
      .init(station: 1)
    )))
    await store.send(.inner(.homeWalkUnavailable("old")))
  }

  // MARK: - 카드 문구와 출발 판단

  @Test("Apple 지도 계산값으로 역·정류장 도보 분을 보인다")
  func showsEstimatedWalkMinutes() throws {
    var state = homeState()
    state.homeWalk = .estimated(
      festivalID,
      .init(
        station: 8,
        shuttleStop: 3
      )
    )
    let ride = try #require(FestivalLiveBoardScreenModel(state: state).homeRide(now: at("23:00")))

    #expect(ride.remain == "막차까지 52분")
    #expect(ride.shuttle == "마지막 셔틀 23:40 · 정문 셔틀 정류장 (도보 3분)")
    #expect(ride.train == "막차 23:52 · 서현역 (도보 8분)")
  }

  @Test("위치를 쓸 수 없으면 서버 도보 분을 보이고 정류장 도보 분은 비운다")
  func showsServerWalkMinutesWhenUnavailable() throws {
    var state = homeState()
    state.homeWalk = .unavailable(festivalID)
    let ride = try #require(FestivalLiveBoardScreenModel(state: state).homeRide(now: at("23:00")))

    #expect(ride.shuttle == "마지막 셔틀 23:40 · 정문 셔틀 정류장")
    #expect(ride.train == "막차 23:52 · 서현역 (도보 12분)")
  }

  @Test("걸어서 막차에 늦으면 아직 탈 수 있는 셔틀을 안내한다")
  func choosesReachableShuttle() throws {
    var state = homeState(directions: directions(lastShuttleAt: "2026-11-08T23:58:00+09:00"))
    state.homeWalk = .estimated(
      festivalID,
      .init(
        station: 8,
        shuttleStop: 3
      )
    )
    let ride = try #require(FestivalLiveBoardScreenModel(state: state).homeRide(now: at("23:45")))

    #expect(ride.remain == "셔틀까지 13분")
  }

  @Test("걸어서 닿는 편이 없으면 아직 떠나지 않은 막차를 그대로 안내한다")
  func keepsFirstUpcomingWhenNoneReachable() throws {
    var state = homeState(directions: directions(lastShuttleAt: "2026-11-08T23:58:00+09:00"))
    state.homeWalk = .estimated(
      festivalID,
      .init(
        station: 10,
        shuttleStop: 20
      )
    )
    let ride = try #require(FestivalLiveBoardScreenModel(state: state).homeRide(now: at("23:45")))

    #expect(ride.remain == "막차까지 7분")
  }

  // MARK: - "가는 길"과 Apple 지도

  @Test("가는 길은 카드가 안내하는 막차의 역으로 Apple 지도 도보 길찾기를 연다")
  func opensAppleMapsToStation() async {
    let opened = LockIsolated<[WalkingPlace]>([])
    let store = TestStore(initialState: homeState()) {
      FestivalFeature()
    } withDependencies: {
      $0.date.now = at("23:00")
      $0.appleMapsClient = MockAppleMapsClient(openWalkingDirections: { place in
        opened.withValue { $0.append(place) }
        return true
      })
    }

    await store.send(.view(.homeDirectionsTapped))
    await store.receive(\.async.openHomeDirections)
    #expect(opened.value.map(\.name) == [stationName])
  }

  @Test("셔틀을 안내하는 중이면 가는 길은 셔틀 정류장으로 연다")
  func opensAppleMapsToShuttleStop() async {
    let opened = LockIsolated<[WalkingPlace]>([])
    var state = homeState(directions: directions(lastShuttleAt: "2026-11-08T23:58:00+09:00"))
    state.homeWalk = .estimated(
      festivalID,
      .init(
        station: 8,
        shuttleStop: 3
      )
    )
    let store = TestStore(initialState: state) {
      FestivalFeature()
    } withDependencies: {
      $0.date.now = at("23:45")
      $0.appleMapsClient = MockAppleMapsClient(openWalkingDirections: { place in
        opened.withValue { $0.append(place) }
        return true
      })
    }

    await store.send(.view(.homeDirectionsTapped))
    await store.receive(\.async.openHomeDirections)
    #expect(opened.value.map(\.name) == [shuttleStopName])
  }

  @Test("Apple 지도를 열지 못하면 기존 팩 상세 가는 길로 보낸다")
  func fallsBackToPackDirectionsWhenMapsFails() async {
    let store = TestStore(initialState: homeState()) {
      FestivalFeature()
    } withDependencies: {
      $0.date.now = at("23:00")
      $0.appleMapsClient = MockAppleMapsClient(openWalkingDirections: { _ in false })
    }

    await store.send(.view(.homeDirectionsTapped))
    await store.receive(\.async.openHomeDirections)
    await store.receive(\.inner.homeDirectionsMapsFailed)
    await store.receive(\.delegate.packDirectionsRequested)
  }

  @Test("안내할 역·정류장이 없으면 바로 팩 상세 가는 길로 보낸다")
  func sendsPackDirectionsWithoutPlace() async {
    let store = TestStore(initialState: homeState(directions: .init(lastTrainAt: "23:52"))) {
      FestivalFeature()
    } withDependencies: {
      $0.date.now = at("23:00")
    }

    await store.send(.view(.homeDirectionsTapped))
    await store.receive(\.delegate.packDirectionsRequested)
  }
}

// MARK: - 고정 값

private let festivalID = "fst"
private let stationName = "서현역"
private let shuttleStopName = "정문 셔틀 정류장"
private let origin = LocationCoordinate(
  latitude: 37.3900,
  longitude: 127.1200
)
private let venueCoordinate = LocationCoordinate(
  latitude: 37.3850,
  longitude: 127.1230
)

private func directions(
  lastShuttleAt: String = "2026-11-08T23:40:00+09:00",
  stationLocation: FestivalPackDetail.Coordinate? = nil
) -> FestivalPackDetail.Directions {
  return FestivalPackDetail.Directions(
    lastShuttleAt: lastShuttleAt,
    lastTrainAt: "2026-11-08T23:52:00+09:00",
    shuttle: .init(
      body: nil,
      stopName: shuttleStopName
    ),
    transit: .init(
      body: nil,
      stationName: stationName,
      walkMinutes: 12,
      location: stationLocation
    ),
    venueLocation: .init(
      latitude: venueCoordinate.latitude,
      longitude: venueCoordinate.longitude
    )
  )
}

private func homeState(directions: FestivalPackDetail.Directions = directions()) -> FestivalFeature.State {
  var state = FestivalFeature.State(selectedFestivalID: festivalID)
  state.catalog = [FestivalCatalogItem(
    id: festivalID,
    name: "원더리벳 2026",
    packVersion: 1
  )]
  state.selectedPack = try? JSONDecoder().decode(
    FestivalPackDocument.self,
    from: Data(#"{"id":"fst","name":"원더리벳 2026"}"#.utf8)
  )
  state.homeDetails = .loaded(
    festivalID,
    directions
  )
  return state
}

/// 역 7분 10초(8분), 정류장 2분 30초(3분)
private func routeClient() -> MockAppleMapsClient {
  return MockAppleMapsClient(walkingDuration: { from, place in
    #expect(from == origin)
    #expect(place.searchCenter == venueCoordinate)
    return place.name == stationName
      ? WalkingDuration(seconds: 430)
      : WalkingDuration(seconds: 150)
  })
}

private func at(_ time: String) -> Date {
  return "2026-11-08T\(time):00+09:00".isoDate ?? .distantPast
}
