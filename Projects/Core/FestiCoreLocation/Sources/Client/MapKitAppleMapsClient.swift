//
//  MapKitAppleMapsClient.swift
//  FestiCoreLocation
//
//  Created by FestiCore on 11/8/26.
//

import CoreLocation
import FestiCoreLocationInterface
import MapKit

/// MapKit으로 목적지를 찾고 도보 시간을 계산하거나 Apple 지도 앱에서 도보 길찾기를 연다.
struct MapKitAppleMapsClient: AppleMapsClient {
  func walkingDuration(
    from origin: LocationCoordinate,
    to place: WalkingPlace
  ) async throws -> WalkingDuration {
    let destination = try await MapKitRouting.coordinate(of: place)
    let seconds = try await MapKitRouting.walkingSeconds(
      from: origin,
      to: destination
    )
    return WalkingDuration(seconds: seconds)
  }

  func openWalkingDirections(to place: WalkingPlace) async -> Bool {
    guard let destination = try? await MapKitRouting.coordinate(of: place) else { return false }
    return await MapKitRouting.openWalkingDirections(
      to: destination,
      name: place.name
    )
  }
}

/// MapKit 객체는 메인 액터에서만 만들고 쓴다.
@MainActor
enum MapKitRouting {
  /// 이름으로 찾을 때 축제 장소에서 이 거리 안의 후보만 목적지로 쓴다.
  static let searchRadius: CLLocationDistance = 5_000

  /// 서버 좌표가 있으면 그대로 쓰고, 없으면 이름을 축제 장소 근처에서 찾는다.
  /// 축제 장소 좌표도 없으면 같은 이름의 다른 지역 장소를 고를 수 있어 찾지 않는다.
  static func coordinate(of place: WalkingPlace) async throws -> LocationCoordinate {
    if let coordinate = place.coordinate, coordinate.isValid { return coordinate }
    guard let center = place.searchCenter, center.isValid else { throw LocationClientError.placeNotFound }
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = place.name
    request.resultTypes = [
      .pointOfInterest,
      .address
    ]
    request.region = MKCoordinateRegion(
      center: CLLocationCoordinate2D(center),
      latitudinalMeters: searchRadius * 2,
      longitudinalMeters: searchRadius * 2
    )
    let candidates: [LocationCoordinate]
    do {
      let response = try await MKLocalSearch(request: request).start()
      candidates = response.mapItems.map { LocationCoordinate($0.placemark.coordinate) }
    } catch {
      throw LocationClientError.placeNotFound
    }
    guard let match = NearestPlace.match(
      candidates,
      near: center,
      within: searchRadius
    ) else { throw LocationClientError.placeNotFound }
    return match
  }

  static func walkingSeconds(
    from origin: LocationCoordinate,
    to destination: LocationCoordinate
  ) async throws -> TimeInterval {
    let request = MKDirections.Request()
    request.source = mapItem(origin)
    request.destination = mapItem(destination)
    request.transportType = .walking
    do {
      let response = try await MKDirections(request: request).calculateETA()
      return response.expectedTravelTime
    } catch {
      throw LocationClientError.routeUnavailable
    }
  }

  static func openWalkingDirections(
    to destination: LocationCoordinate,
    name: String
  ) -> Bool {
    let item = mapItem(destination)
    item.name = name
    return item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
  }

  private static func mapItem(_ coordinate: LocationCoordinate) -> MKMapItem {
    return MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(coordinate)))
  }
}
