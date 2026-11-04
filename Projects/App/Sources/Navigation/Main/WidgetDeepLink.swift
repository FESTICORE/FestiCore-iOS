import Foundation

/// Widget 탭에서 앱의 축제 목록 또는 저장된 축제 팩으로 이동한다.
enum WidgetDeepLink: Equatable {
  case festivalList
  case festival(String)

  init?(url: URL) {
    guard let components = URLComponents(
      url: url,
      resolvingAgainstBaseURL: false
    ),
          components.scheme?.lowercased() == "festicore",
          components.host?.lowercased() == "festival",
          components.user == nil,
          components.password == nil,
          components.port == nil,
          components.query == nil,
          components.fragment == nil else { return nil }

    if components.percentEncodedPath.isEmpty {
      self = .festivalList
      return
    }

    let path = components.percentEncodedPath
    guard path.hasPrefix("/"),
          !path.dropFirst().contains("/"),
          let id = String(path.dropFirst()).removingPercentEncoding,
          !id.isEmpty,
          id != ".",
          id != "..",
          id.rangeOfCharacter(from: .controlCharacters.union(.whitespacesAndNewlines)) == nil,
          !id.contains("/") else { return nil }
    self = .festival(id)
  }
}
