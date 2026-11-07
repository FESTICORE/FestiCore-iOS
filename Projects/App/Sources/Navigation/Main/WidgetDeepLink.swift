import Foundation

/// Widget 탭에서 앱의 축제 목록 또는 저장된 축제 팩으로 이동한다.
/// 깃발 공유 링크(`festicore://flag/<id>`)는 깃발 상세를 연다.
enum WidgetDeepLink: Equatable {
  case festivalList
  case festival(String)
  case flag(String)

  init?(url: URL) {
    guard let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ),
          components.scheme?.lowercased() == "festicore",
          components.user == nil,
          components.password == nil,
          components.port == nil,
          components.query == nil,
          components.fragment == nil else { return nil }

    switch components.host?.lowercased() {
    case "festival":
      guard let route = Self.festivalRoute(components.percentEncodedPath) else { return nil }
      self = route
    case "flag":
      guard let id = Self.flagID(components.percentEncodedPath) else { return nil }
      self = .flag(id)
    default:
      return nil
    }
  }
}

private extension WidgetDeepLink {
  static func festivalRoute(_ path: String) -> WidgetDeepLink? {
    if path.isEmpty { return .festivalList }
    guard path.hasPrefix("/"),
          !path.dropFirst().contains("/"),
          let id = String(path.dropFirst()).removingPercentEncoding,
          !id.isEmpty,
          id != ".",
          id != "..",
          id.rangeOfCharacter(from: .controlCharacters.union(.whitespacesAndNewlines)) == nil,
          !id.contains("/") else { return nil }
    return .festival(id)
  }

  /// 깃발 ID는 서버 ID 형식(ASCII 영숫자·`-`·`_`)만 받는다. 상세 조회가 거부할 링크는 화면을 열지 않는다.
  static func flagID(_ path: String) -> String? {
    guard path.hasPrefix("/") else { return nil }
    let id = path.dropFirst()
    guard !id.isEmpty,
          id.unicodeScalars.allSatisfy(isFlagIDCharacter) else { return nil }
    return String(id)
  }

  static func isFlagIDCharacter(_ scalar: Unicode.Scalar) -> Bool {
    return scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_")
  }
}
