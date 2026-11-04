import FestiCoreDesignKit
import FestiCoreUtility
import SwiftUI

/// Figma S00 페스티벌 목록. 전체·예매 완료 탭과 검색(최근 검색·다가오는 페스티벌·결과·결과 없음)을 보여 준다.
struct FestivalListView: View {
  let userID: String?
  let recentSearches: [String]
  let festivals: [FestivalOverview]
  let bookedFestivalIDs: Set<String>
  let packDownloads: [String: FestivalFeature.PackDownloadStatus]
  let imageRevision: Int
  let isLoading: Bool
  let hasCatalogFailure: Bool
  let offlineMessage: String?
  let imageURL: (String?) -> URL?
  let onSelect: (String) -> Void
  let onToggleBooked: (String) -> Void
  let onDownloadPack: (String) -> Void
  let onTicketLink: (FestivalOverview) -> Void
  let onRefresh: () -> Void
  let onRecentSearchSubmitted: (String) -> Void
  let onRecentSearchRemoved: (String) -> Void
  let onRecentSearchesCleared: () -> Void

  @State private var selectedFilter = 0
  @State private var isSearching = false
  @State private var query = ""

  var body: some View {
    VStack(spacing: .zero) {
      if isSearching {
        searchBar
        offlineBadge
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
        .indicatorColor(FestiCoreSemanticColor.staticLime.color)
        offlineBadge
        ScrollView {
          LazyVStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
            listContent
          }
          .padding(.horizontal, FestiCoreSpacing.paddingP16)
          .padding(.bottom, FestiCoreSpacing.paddingP16)
          .padding(.top, FestiCoreSpacing.paddingP16 * 2)
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

  // MARK: - 검색

  // MARK: - 표시 문구
}

private extension FestivalListView {
  var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var visibleFestivals: [FestivalOverview] {
    FestivalListPresentation.sorted(
      FestivalListPresentation.visible(
        festivals,
        query: "",
        bookedIDs: bookedFestivalIDs,
        onlyBooked: selectedFilter == 1
      ),
      now: .now
    )
  }

  var searchResults: [FestivalOverview] {
    FestivalListPresentation.sorted(
      FestivalListPresentation.visible(
        festivals,
        query: trimmedQuery,
        bookedIDs: bookedFestivalIDs,
        onlyBooked: false
      ),
      now: .now
    )
  }

  var artistResults: [FestivalListPresentation.ArtistSearchResult] {
    FestivalListPresentation.matchingArtists(FestivalListPresentation.sorted(festivals, now: .now), query: trimmedQuery)
  }

  var supportsArtistSearch: Bool {
    festivals.contains { $0.artists != nil }
  }

  var upcomingFestivals: [FestivalOverview] {
    FestivalListPresentation.sorted(festivals.filter {
      guard !FestivalListPresentation.isOpeningSoon($0) else { return false }
      if case .daysUntil = FestivalListPresentation.timing(for: $0, now: .now) { return true }
      return false
    }, now: .now)
  }

  /// 목록을 좌우로 밀면 전체·예매 완료 탭을 바꾼다.
  var filterSwipe: some Gesture {
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
  var listContent: some View {
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
  var emptyCard: some View {
    if festivals.isEmpty {
      FCEmptyCard(
        icon: .bell,
        title: "불러온 페스티벌이 없어요",
        message: hasCatalogFailure
          ? "연결을 확인하고 다시 시도해 주세요."
          : "새 페스티벌이 등록되면 여기에 표시해요."
      )
      .action(hasCatalogFailure ? FCCardAction("다시 시도", action: onRefresh) : nil)
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

  func festivalCard(_ festival: FestivalOverview) -> some View {
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
    .pack(pack(for: festival))
    .booked(
      bookedFestivalIDs.contains(festival.id),
      onToggle: { onToggleBooked(festival.id) }
    )
    .ticketLink { onTicketLink(festival) }
    .onTapGesture { onSelect(festival.id) }
    .accessibilityIdentifier(FestivalAccessibilityID.card(festival.id))
  }

  @ViewBuilder
  var offlineBadge: some View {
    if let offlineMessage {
      FCOfflineBadge(offlineMessage)
    }
  }

  var searchBar: some View {
    FCTopBar(.search(text: $query))
      .searchPlaceholder(supportsArtistSearch ? "페스티벌, 아티스트, 장소 검색" : "페스티벌, 장소 검색")
      .onCancel {
        query = ""
        isSearching = false
      }
      .onSubmit { saveRecentSearch() }
  }

  @ViewBuilder
  var searchContent: some View {
    if isLoading {
      searchSkeleton
    } else if festivals.isEmpty && hasCatalogFailure {
      FCEmptyCard(
        icon: .bell,
        title: "페스티벌을 불러오지 못했어요",
        message: "연결을 확인하고 다시 시도해 주세요."
      )
      .action(FCCardAction("다시 시도", action: onRefresh))
      .padding(FestiCoreSpacing.paddingP16)
    } else if trimmedQuery.isEmpty {
      VStack(alignment: .leading, spacing: .zero) {
        if !recentSearches.isEmpty {
          FCSectionHeader("최근 검색")
            .action("전체 삭제", perform: onRecentSearchesCleared)
            .padding(.top, FestiCoreSpacing.paddingP20)
            .padding(.bottom, FestiCoreSpacing.paddingP8)
            .padding(.horizontal, FestiCoreSpacing.paddingP16)
          FCFlowLayout {
            ForEach(recentSearches, id: \.self) { keyword in
              FCRecentKeyword(
                keyword,
                onSelect: { query = keyword },
                onDelete: { onRecentSearchRemoved(keyword) }
              )
            }
          }
          .spacing(FestiCoreSpacing.paddingP8)
          .padding(.horizontal, FestiCoreSpacing.paddingP16)
        }
        if !upcomingFestivals.isEmpty {
          FCSectionHeader("다가오는 페스티벌")
            .padding(.top, FestiCoreSpacing.paddingP20)
            .padding(.bottom, FestiCoreSpacing.paddingP8)
            .padding(.horizontal, FestiCoreSpacing.paddingP16)
          resultRows(upcomingFestivals)
        } else if recentSearches.isEmpty {
          FCEmptyCard(
            icon: .bell,
            title: "다가오는 페스티벌이 없어요",
            message: "새 페스티벌이 등록되면 여기에서 찾아볼 수 있어요."
          )
          .padding(FestiCoreSpacing.paddingP16)
        }
      }
    } else if searchResults.isEmpty && artistResults.isEmpty {
      FCSearchEmpty(query: trimmedQuery)
        .message(supportsArtistSearch
          ? "페스티벌, 아티스트 이름이나 장소로 다시 찾아보세요"
          : "페스티벌 이름이나 장소로 다시 찾아보세요")
    } else {
      VStack(alignment: .leading, spacing: .zero) {
        if !searchResults.isEmpty {
          FCSectionHeader("페스티벌 \(searchResults.count)")
            .padding(.top, FestiCoreSpacing.paddingP20)
            .padding(.bottom, FestiCoreSpacing.paddingP8)
            .padding(.horizontal, FestiCoreSpacing.paddingP16)
          resultRows(searchResults)
        }
        if !artistResults.isEmpty {
          FCSectionHeader("아티스트 \(artistResults.count)")
            .padding(.top, FestiCoreSpacing.paddingP20)
            .padding(.bottom, FestiCoreSpacing.paddingP8)
            .padding(.horizontal, FestiCoreSpacing.paddingP16)
          artistResultRows
        }
      }
    }
  }

  var searchSkeleton: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      FCSkeletonView(.round())
        .frame(width: 120, height: 20)
      ForEach(0..<3, id: \.self) { _ in
        HStack(spacing: FestiCoreSpacing.paddingP12) {
          FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r12))
            .frame(width: 48, height: 48)
          VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
            FCSkeletonView(.round())
              .frame(width: 180, height: 18)
            FCSkeletonView(.round())
              .frame(width: 230, height: 16)
          }
        }
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .accessibilityIdentifier(FestivalAccessibilityID.searchSkeleton)
  }

  func resultRows(_ items: [FestivalOverview]) -> some View {
    LazyVStack(spacing: .zero) {
      ForEach(items) { festival in
        FCSearchResultRow(
          .festival(
            image: nil,
            dDay: FestivalListPresentation.searchBadge(for: festival, now: .now)
          ),
          title: festival.name,
          meta: meta(for: festival),
          action: {
            saveRecentSearch()
            onSelect(festival.id)
          }
        )
        .highlightedQuery(trimmedQuery)
        .urgent(isUrgent(festival))
        .thumbnail(
          FestivalPosterView(
            url: imageURL(festival.thumbnailURL?.absoluteString),
            imageRevision: imageRevision
          )
        )
      }
    }
  }

  var artistResultRows: some View {
    LazyVStack(spacing: .zero) {
      ForEach(artistResults) { result in
        FCSearchResultRow(
          .artist(initial: String(result.artist.name.prefix(1))),
          title: result.artist.name,
          meta: FestivalListPresentation.artistMeta(result, now: .now),
          action: {
            saveRecentSearch()
            onSelect(result.festival.id)
          }
        )
        .highlightedQuery(trimmedQuery)
      }
    }
  }

  func saveRecentSearch() {
    guard !trimmedQuery.isEmpty else { return }
    onRecentSearchSubmitted(trimmedQuery)
  }

  func status(for festival: FestivalOverview) -> FCFestivalCard<FestivalPosterView>.Status {
    switch FestivalListPresentation.cardStatus(for: festival, now: .now) {
    case let .dDay(label): .dDay(label)
    case let .closing(label): .closing(label)
    case .upcoming: .upcoming()
    case .ended: .ended()
    }
  }

  func pack(for festival: FestivalOverview) -> FCFestivalCard<FestivalPosterView>.Pack {
    if case let .some(.downloading(progress)) = packDownloads[festival.id] {
      let fraction = progress.flatMap { value -> Double? in
        guard value.totalBytes > 0 else { return nil }
        return min(max(Double(value.receivedBytes) / Double(value.totalBytes), 0), 1)
      }
      let text = fraction.map { "팩 받는 중 · \(Int(($0 * 100).rounded()))%" } ?? "팩 받는 중"
      return .downloading(progress: fraction, text: text)
    }
    let copy = FestivalListPresentation.packCopy(
      for: festival,
      isBooked: bookedFestivalIDs.contains(festival.id),
      onlyBooked: selectedFilter == 1,
      now: .now
    )
    return switch copy {
    case let .unavailable(text): .unavailable(text)
    case let .ready(title): .ready(title: title, action: { onDownloadPack(festival.id) })
    case let .received(text): .received(text)
    }
  }

  func isUrgent(_ festival: FestivalOverview) -> Bool {
    if case .closing = FestivalListPresentation.cardStatus(for: festival, now: .now) { return true }
    return false
  }

  func meta(for festival: FestivalOverview) -> String {
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
