//
//  FestiCoreDeeplink.swift
//  FestiCoreUtility
//
//  Created by FestiCore on 11/8/26.
//

import Foundation

/// 앱이 여는 화면 경로. 위젯 URL·푸시 payload·알림함 항목이 모두 이 값으로 모인다.
public enum FestiCoreDeeplink: Equatable, Sendable {
  /// 축제 목록(S00).
  case festivalList
  /// 축제 라이브 보드(S01).
  case festival(id: String)
  /// 깃발 상세(S05).
  case flag(id: String)
  /// 축제 타임테이블의 공연 상세(S03). 공연 2시간 전 알림이 연다.
  case set(
    festivalID: String,
    setID: String
  )
  /// 크루 초대(`festicore://crew/<초대 코드>`). 크루 참여 확인(S08)을 연다.
  case crewInvite(code: String)

  /// 대기 저장용 URL 문자열. `FestiCoreDeeplinkParser.parse(urlString:)`로 되돌린다.
  public var encoded: String {
    switch self {
    case .festivalList:
      return "festicore://festival"
    case let .festival(id):
      return "festicore://festival/\(Self.escape(id))"
    case let .flag(id):
      return "festicore://flag/\(Self.escape(id))"
    case let .set(
      festivalID,
      setID
    ):
      return "festicore://festival/\(Self.escape(festivalID))/set/\(Self.escape(setID))"
    case let .crewInvite(code):
      return "festicore://crew/\(Self.escape(code))"
    }
  }

  private static func escape(_ value: String) -> String {
    let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }
}

public enum FestiCoreDeeplinkParser {
  /// 푸시 userInfo에서 딥링크를 읽는다. `deeplink` URL이 우선이고, 없으면 기존 `route`·ID 필드로 찾는다.
  public static func parse(pushPayload userInfo: [AnyHashable: Any]) -> FestiCoreDeeplink? {
    if let deeplink = (userInfo["deeplink"] as? String).flatMap(parse(urlString:)) {
      return deeplink
    }
    if let route = (userInfo["route"] as? String).flatMap(parse(route:)) {
      return route
    }
    if let flagID = validID(userInfo["flagId"] as? String) {
      return .flag(id: flagID)
    }
    if let festivalID = validID(userInfo["festivalId"] as? String) {
      return .festival(id: festivalID)
    }
    return nil
  }

  /// `festicore://festival`, `festicore://festival/<id>`, `festicore://festival/<id>/set/<setId>`, `festicore://flag/<id>`,
  /// `festicore://crew/<초대 코드>`.
  public static func parse(urlString: String) -> FestiCoreDeeplink? {
    return URL(string: urlString).flatMap(parse(url:))
  }

  public static func parse(url: URL) -> FestiCoreDeeplink? {
    guard let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ),
          components.scheme?.lowercased() == "festicore",
          components.user == nil,
          components.password == nil,
          components.port == nil,
          components.query == nil,
          components.fragment == nil,
          let host = components.host?.lowercased() else { return nil }
    guard let segments = pathSegments(components.percentEncodedPath) else { return nil }
    return route(
      resource: host,
      segments: segments
    )
  }

  /// 서버 알림의 `route`(`/festivals/<id>/live`, `/flags/<id>` 등). `/crews/<id>`처럼 축제를 모르는 경로는 처리하지 않는다.
  public static func parse(route: String) -> FestiCoreDeeplink? {
    guard route.hasPrefix("/"),
          let segments = pathSegments(route),
          let resource = segments.first else { return nil }
    let rest = Array(segments.dropFirst())
    switch resource {
    case "festivals":
      guard let id = rest.first else { return .festivalList }
      return .festival(id: id)
    case "flags":
      return rest.first.map { .flag(id: $0) }
    default:
      return nil
    }
  }
}

private extension FestiCoreDeeplinkParser {
  static func route(
    resource: String,
    segments: [String]
  ) -> FestiCoreDeeplink? {
    switch resource {
    case "festival":
      return festivalRoute(segments)
    case "flag":
      return segments.count == 1 ? .flag(id: segments[0]) : nil
    case "crew":
      return segments.count == 1 ? inviteCode(segments[0]).map { .crewInvite(code: $0) } : nil
    default:
      return nil
    }
  }

  /// 초대 코드는 헷갈리는 글자(I·O·0·1)를 뺀 영숫자 6자리다. 대문자로 맞춘다.
  static func inviteCode(_ value: String) -> String? {
    let code = value.uppercased()
    let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    guard code.count == 6,
          code.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
    return code
  }

  static func festivalRoute(_ segments: [String]) -> FestiCoreDeeplink? {
    if segments.isEmpty { return .festivalList }
    if segments.count == 1 { return .festival(id: segments[0]) }
    guard segments.count == 3, segments[1] == "set" else { return nil }
    return .set(
      festivalID: segments[0],
      setID: segments[2]
    )
  }

  /// 빈 경로는 [], 각 조각은 퍼센트 디코딩 후 서버 ID 형식(ASCII 영숫자·`-`·`_`)만 받는다.
  static func pathSegments(_ path: String) -> [String]? {
    guard !path.isEmpty else { return [] }
    guard path.hasPrefix("/") else { return nil }
    var segments: [String] = []
    for raw in path.dropFirst().split(
      separator: "/",
      omittingEmptySubsequences: false
    ) {
      guard let segment = validID(String(raw).removingPercentEncoding) else { return nil }
      segments.append(segment)
    }
    return segments
  }

  static func validID(_ value: String?) -> String? {
    guard let value, !value.isEmpty,
          value.unicodeScalars.allSatisfy(isIDCharacter) else { return nil }
    return value
  }

  static func isIDCharacter(_ scalar: Unicode.Scalar) -> Bool {
    return scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_")
  }
}

public extension Notification.Name {
  /// 새 딥링크가 대기 저장소에 들어왔음을 알린다. 받는 쪽은 홈이 준비됐을 때 대기 값을 꺼낸다.
  static let festiCoreDeeplink = Notification.Name("FestiCoreDeeplink")
}
