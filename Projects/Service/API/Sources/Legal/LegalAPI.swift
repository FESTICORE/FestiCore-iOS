import Foundation

/// 약관 상세 경로와 앱 설정의 API 호스트를 조합한다.
public enum LegalAPI: String, Sendable {
  case terms
  case privacy

  public var path: String {
    return rawValue
  }

  public static var basePath: String {
    return "\(FestiCoreDomain.legal.path)/"
  }

  public static var baseURL: URL? {
    return baseURL(
      host: Bundle.main.object(forInfoDictionaryKey: "FestiCoreAPIHost") as? String
    )
  }

  public static func baseURL(host: String?) -> URL? {
    guard let host, !host.isEmpty else { return nil }
    return URL(string: "https://\(host)/\(basePath)")
  }
}
