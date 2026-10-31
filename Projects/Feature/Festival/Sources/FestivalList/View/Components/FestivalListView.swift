import FestiCoreDesignKit
import FestiCoreUtility
import SwiftUI

/// Figma S00 페스티벌 목록. 전체·예매 완료 탭과 검색(최근 검색·다가오는 페스티벌·결과·결과 없음)을 보여 준다.
struct FestivalListView: View {
  let userID: String?
  let recentSearches: [String]
  let festivals: [FestivalOverview]
  let bookedFestivalIDs: Set<String>
  let imageRevision: Int
  let isLoading: Bool
  let imageURL: (String?) -> URL?
  let onSelect: (String) -> Void
  let onToggleBooked: (String) -> Void
  let onRefresh: () -> Void
  let onRecentSearchSubmitted: (String) -> Void
  let onRecentSearchRemoved: (String) -> Void
  let onRecentSearchesCleared: () -> Void

  @State private var selectedFilter = 0
  @State private var isSearching = false
  @State private var query = ""

  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var visibleFestivals: [FestivalOverview] {
    FestivalListPresentation.visible(
      festivals,
      query: "",
      bookedIDs: bookedFestivalIDs,
      onlyBooked: selectedFilter == 1
    )
  }

  private var searchResults: [FestivalOverview] {
    FestivalListPresentation.visible(
      festivals,
      query: trimmedQuery,
      bookedIDs: bookedFestivalIDs,
      onlyBooked: false
    )
  }

  private var upcomingFestivals: [FestivalOverview] {
    festivals.filter {
      if case .daysUntil = FestivalListPresentation.timing(for: $0, now: .now) {
        return true
      }
      return false
    }
  }

  var body: some View {
    VStack(spacing: .zero) {
      if isSearching {
        searchBar
        ScrollView {
          searchContent
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
      } else {
        FCTopBar(
          .large,
          title: "페스티벌"
        )
        .trailingAction { isSearching = true }
        FCTab(
          selection: $selectedFilter,
          items: ["전체", "예매 완료"]
        )
        ScrollView {
          LazyVStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
            listContent
          }
          .padding(FestiCoreSpacing.paddingP16)
        }
        .scrollIndicators(.hidden)
        .refreshable { onRefresh() }
        .simultaneousGesture(filterSwipe)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .animation(.easeOut(duration: Metric.duration), value: isSearching)
    .onChange(of: userID) { _, _ in
      isSearching = false
      query = ""
      selectedFilter = 0
    }
  }

  // MARK: - 목록

  /// 목록을 좌우로 밀면 전체·예매 완료 탭을 바꾼다.
  private var filterSwipe: some Gesture {
    DragGesture(minimumDistance: Metric.swipeMinimumDistance)
      .onEnded { value in
        let horizontal = value.translation.width
        guard abs(horizontal) > Metric.swipeThreshold,
              abs(horizontal) > abs(value.translation.height) * Metric.swipeRatio
        else { return }
        selectedFilter = horizontal < 0 ? 1 : 0
      }
  }

  @ViewBuilder
  private var listContent: some View {
    Text(selectedFilter == 0 ? Copy.allGuide : Copy.bookedGuide)
      .festiCoreFont(.baseSubheadlineMedium)
      .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    if isLoading {
      FestivalListSkeletonView()
    } else if visibleFestivals.isEmpty {
      emptyCard
    } else {
      ForEach(visibleFestivals) { festival in
        festivalCard(festival)
      }
    }
  }

  @ViewBuilder
  private var emptyCard: some View {
    if festivals.isEmpty {
      FCEmptyCard(
        icon: .bell,
        title: "불러온 페스티벌이 없어요",
        message: "연결되면 페스티벌 목록을 가져와요."
      )
    } else {
      FCEmptyCard(
        icon: .bookmark20,
        title: "북마크한 페스티벌이 없어요",
        message: "예매한 페스티벌을 북마크하면 여기에 모아 볼 수 있어요."
      )
      .action(
        FCCardAction(
          "전체 보기",
          action: { selectedFilter = 0 }
        )
      )
    }
  }

  private func festivalCard(_ festival: FestivalOverview) -> some View {
    FCFestivalCard(
      title: festival.name,
      meta: meta(for: festival),
      status: status(for: festival)
    ) {
      FestivalPosterView(
        url: imageURL(festival.thumbnailURL?.absoluteString),
        imageRevision: imageRevision
      )
    }
    .pack(
      festival.isCached
        ? .received("오프라인 팩 저장됨")
        : festival.packVersion > 0
        ? .ready(action: { onSelect(festival.id) })
        : .unavailable("오프라인 팩 공개 전")
    )
    .booked(
      bookedFestivalIDs.contains(festival.id),
      onToggle: { onToggleBooked(festival.id) }
    )
    .onTapGesture { onSelect(festival.id) }
    .accessibilityIdentifier("festivalCard_\(festival.id)")
  }

  // MARK: - 검색

  private var searchBar: some View {
    FCTopBar(.search(text: $query))
      .searchPlaceholder("페스티벌, 장소 검색")
      .onCancel {
        query = ""
        isSearching = false
      }
      .onSubmit { saveRecentSearch() }
  }

  @ViewBuilder
  private var searchContent: some View {
    if trimmedQuery.isEmpty {
      VStack(alignment: .leading, spacing: .zero) {
        if !recentSearches.isEmpty {
          FCSectionHeader("최근 검색")
            .action("전체 삭제", perform: onRecentSearchesCleared)
            .padding(.top, FestiCoreSpacing.paddingP20)
            .padding(.bottom, FestiCoreSpacing.paddingP8)
            .padding(.horizontal, FestiCoreSpacing.paddingP16)
          ScrollView(.horizontal) {
            HStack(spacing: FestiCoreSpacing.paddingP8) {
              ForEach(recentSearches, id: \.self) { keyword in
                FCRecentKeyword(
                  keyword,
                  onSelect: { query = keyword },
                  onDelete: { onRecentSearchRemoved(keyword) }
                )
              }
            }
            .padding(.horizontal, FestiCoreSpacing.paddingP16)
          }
          .scrollIndicators(.hidden)
        }
        if !upcomingFestivals.isEmpty {
          FCSectionHeader("다가오는 페스티벌")
            .padding(.top, FestiCoreSpacing.paddingP20)
            .padding(.bottom, FestiCoreSpacing.paddingP8)
            .padding(.horizontal, FestiCoreSpacing.paddingP16)
          resultRows(upcomingFestivals)
        }
      }
    } else if searchResults.isEmpty {
      FCSearchEmpty(query: trimmedQuery)
        .message("페스티벌 이름이나 장소로 다시 찾아보세요")
    } else {
      VStack(alignment: .leading, spacing: .zero) {
        FCSectionHeader("페스티벌 \(searchResults.count)")
          .padding(.top, FestiCoreSpacing.paddingP20)
          .padding(.bottom, FestiCoreSpacing.paddingP8)
          .padding(.horizontal, FestiCoreSpacing.paddingP16)
        resultRows(searchResults)
      }
    }
  }

  private func resultRows(_ items: [FestivalOverview]) -> some View {
    LazyVStack(spacing: .zero) {
      ForEach(items) { festival in
        FCSearchResultRow(
          .festival(
            image: nil,
            dDay: dDay(for: festival)
          ),
          title: festival.name,
          meta: meta(for: festival),
          action: {
            saveRecentSearch()
            onSelect(festival.id)
          }
        )
        .thumbnail(
          FestivalPosterView(
            url: imageURL(festival.thumbnailURL?.absoluteString),
            imageRevision: imageRevision
          )
        )
      }
    }
  }

  private func saveRecentSearch() {
    guard !trimmedQuery.isEmpty else { return }
    onRecentSearchSubmitted(trimmedQuery)
  }

  // MARK: - 표시 문구

  private func status(for festival: FestivalOverview) -> FCFestivalCard<FestivalPosterView>.Status {
    switch FestivalListPresentation.timing(for: festival, now: .now) {
    case let .daysUntil(days): .dDay("D-\(days)")
    case .live: .dDay("진행 중")
    case .ended: .ended("종료")
    case .undated: .upcoming("일정 확인")
    }
  }

  private func dDay(for festival: FestivalOverview) -> String? {
    switch FestivalListPresentation.timing(for: festival, now: .now) {
    case let .daysUntil(days): "D-\(days)"
    case .live: "진행 중"
    case .ended, .undated: nil
    }
  }

  private func meta(for festival: FestivalOverview) -> String {
    let dates = [festival.firstDate, festival.lastDate]
      .compactMap { $0?.date(as: .day)?.formatted(.festivalDay) }
      .joined(separator: " – ")
    return [festival.venue, dates.isEmpty ? nil : dates]
      .compactMap { $0 }
      .joined(separator: " · ")
  }
}

private extension FestivalListView {
  enum Copy {
    static let allGuide = "가고 싶은 페스티벌을 찾아보아요.\n이미 예매한 페스티벌은 북마크 해서 따로 모아 볼 수 있어요."
    static let bookedGuide = "북마크한 페스티벌만 모아 봤어요.\n팩을 미리 받아 두면 현장에서 통신이 약해도 볼 수 있어요."
  }

  enum Metric {
    static let duration = 0.2
    static let swipeMinimumDistance: CGFloat = 30
    static let swipeThreshold: CGFloat = 80
    static let swipeRatio: CGFloat = 1.5
  }
}
