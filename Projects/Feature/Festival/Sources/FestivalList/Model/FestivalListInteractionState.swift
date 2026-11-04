import Foundation

/// S00 목록에서만 사용하는 검색과 탭 선택 상태.
public struct FestivalListInteractionState: Equatable {
  public enum Filter: Int {
    case all, booked
  }

  var selectedFilter: Filter = .all
  var isSearching = false
  var query = ""

  var trimmedQuery: String {
    return query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  mutating func reset() {
    self = Self()
  }
}
