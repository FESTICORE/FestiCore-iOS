import Foundation

/// 서버 알림 payload에서 Notification Service Extension이 붙일 묶음·부제목·이미지를 읽는다.
public struct RemoteNotificationEnrichment: Equatable, Sendable {
  /// 같은 축제 알림을 한 묶음으로 보인다. 예: `festival.fst_abc`
  public let threadIdentifier: String?
  /// 축제 이름
  public let subtitle: String?
  /// https 이미지 주소
  public let imageURL: URL?

  public init(userInfo: [AnyHashable: Any]) {
    let festivalID = Self.nonempty(userInfo["festivalId"])
    threadIdentifier = festivalID.map { "festival.\($0)" }
    subtitle = Self.nonempty(userInfo["festivalName"])
    imageURL = Self.nonempty(userInfo["imageUrl"])
      .flatMap(URL.init(string:))
      .flatMap { $0.scheme?.lowercased() == "https" && $0.host?.isEmpty == false ? $0 : nil }
  }

  /// 알림이 이미 가진 값은 그대로 두고 빈 값만 채운다.
  public func threadIdentifier(current: String) -> String? {
    return current.isEmpty ? threadIdentifier : nil
  }

  /// 알림이 이미 가진 부제목은 그대로 두고 빈 값만 채운다.
  public func subtitle(current: String) -> String? {
    return current.isEmpty ? subtitle : nil
  }

  /// 알림 첨부로 쓸 수 있는 이미지 형식의 파일 확장자. JPEG·PNG·GIF만 받는다.
  public static func attachmentFileExtension(mimeType: String?) -> String? {
    switch mimeType?.lowercased() {
    case "image/jpeg", "image/jpg": return "jpg"
    case "image/png": return "png"
    case "image/gif": return "gif"
    default: return nil
    }
  }

  static func nonempty(_ value: Any?) -> String? {
    guard let value = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else { return nil }
    return value
  }
}
