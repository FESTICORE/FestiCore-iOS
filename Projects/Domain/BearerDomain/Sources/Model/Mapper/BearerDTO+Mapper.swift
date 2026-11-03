//
//  BearerDTO+Mapper.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import Foundation

/// 서버 날짜 문자열(밀리초 포함 ISO8601)을 읽는다.
enum BearerDateFormat {
  static func date(from value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }

  /// `clientAt` 본문 값. UTC 밀리초 형식으로 보낸다.
  static func string(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}

/// 서버 사진 경로(`/api/v1/flags/:id/photo`)를 API 호스트 기준 https 주소로 바꾼다.
enum BearerImageURL {
  static func resolve(_ value: String?, baseURL: URL?) -> URL? {
    guard let value, let url = URL(string: value) else { return nil }
    if let scheme = url.scheme?.lowercased() {
      return scheme == "https" ? url : nil
    }
    guard value.hasPrefix("/"), !value.hasPrefix("//"),
          let baseURL, baseURL.scheme?.lowercased() == "https" else { return nil }
    return URL(string: value, relativeTo: baseURL)?.absoluteURL
  }
}

extension BearerFlagProfileDTO {
  func toDomain(baseURL: URL?) -> BearerFlagProfile {
    BearerFlagProfile(
      id: id,
      name: name,
      photoURL: BearerImageURL.resolve(photoUrl, baseURL: baseURL),
      thumbnailURL: BearerImageURL.resolve(thumbUrl, baseURL: baseURL),
      tags: (tags ?? []).compactMap(BearerFlagTag.init(rawValue:)),
      bio: bio,
      followerCount: followerCount ?? 0,
      planVisible: planVisible ?? true,
      plan: plan ?? [],
      homeZoneID: homeZoneId
    )
  }
}

extension BearerFlagStatusDTO {
  func toDomain() throws -> BearerFlagStatus {
    guard let lifecycle = BearerFlagLifecycle(rawValue: status),
          let updated = BearerDateFormat.date(from: updatedAt) else {
      throw BearerError.invalidResponse
    }
    return BearerFlagStatus(
      flagID: flagId,
      lifecycle: lifecycle,
      zoneID: zoneId,
      activity: activity.flatMap(BearerActivity.init(rawValue:)),
      updatedAt: updated,
      updatedBy: updatedBy.map { BearerCoBearer(userID: $0.userId, nickname: $0.nickname ?? "") }
    )
  }
}

extension BearerBoardDataDTO {
  func toDomain(baseURL: URL?) throws -> BearerBoard {
    let profile = flag.toDomain(baseURL: baseURL)
    return BearerBoard(
      profile: profile,
      status: try status.toDomain(),
      followerCount: followerCount ?? profile.followerCount,
      coBearers: (coBearers ?? []).map { BearerCoBearer(userID: $0.userId, nickname: $0.nickname ?? "") },
      hidden: hidden ?? false,
      restartUsedToday: restartUsedToday ?? false
    )
  }
}

extension BearerClaimDataDTO {
  func toDomain(baseURL: URL?) -> BearerClaim {
    BearerClaim(
      flagID: flagId,
      profile: flag.toDomain(baseURL: baseURL),
      isNew: isNew ?? false,
      coBearerIDs: coBearers ?? []
    )
  }
}

extension BearerInviteDataDTO {
  func toDomain() throws -> BearerInvite {
    guard let expires = BearerDateFormat.date(from: expiresAt) else { throw BearerError.invalidResponse }
    return BearerInvite(code: code, expiresAt: expires)
  }
}

extension BearerPackDTO {
  func toDomain(festivalID: String) -> BearerFestival {
    BearerFestival(
      id: festivalID,
      name: name,
      zones: (zones ?? []).compactMap { zone in
        guard let id = zone.id, !id.isEmpty, let name = zone.name else { return nil }
        return BearerZone(id: id, name: name)
      }
    )
  }
}
