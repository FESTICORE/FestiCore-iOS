import Foundation

struct FestivalImageURLResolver: Sendable {
  let baseURL: URL?

  func resolve(_ value: String?) -> URL? {
    guard let value, let url = URL(string: value) else { return nil }
    if let scheme = url.scheme?.lowercased() {
      guard scheme == "https" || scheme == "http" else { return nil }
      return url
    }
    guard value.hasPrefix("/"), !value.hasPrefix("//"), let baseURL else { return nil }
    return URL(string: value, relativeTo: baseURL)?.absoluteURL
  }
}
