import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreUtility
import SwiftUI
import UIKit

/// Figma S00 페스티벌 목록. 전체·예매 완료 탭과 검색(최근 검색·결과·결과 없음)을 보여 준다.
@ViewAction(for: FestivalFeature.self)
struct FestivalListView: View {
  @Bindable var store: StoreOf<FestivalFeature>

  init(store: StoreOf<FestivalFeature>) {
    self.store = store
  }

  var body: some View {
    return VStack(spacing: .zero) {
      if store.listInteraction.isSearching {
        searchBar
        offlineBadge()
        ScrollView {
          searchContent()
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
      } else {
        FCTopBar(
          .large,
          title: "페스티벌"
        )
        .trailingAction { send(.searchOpened) }
        FCTab(
          selection: filterBinding,
          items: ["전체", "예매 완료"]
        )
        .indicatorColor(FestiCoreSemanticColor.staticLime.color)
        offlineBadge()
        ScrollView {
          LazyVStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
            listContent()
          }
          .padding(.horizontal, FestiCoreSpacing.paddingP16)
          .padding(.bottom, FestiCoreSpacing.paddingP16)
          .padding(.top, FestiCoreSpacing.paddingP16 * 2)
        }
        .scrollIndicators(.hidden)
        .refreshable { send(.refreshRequested) }
        .simultaneousGesture(filterSwipe)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .animation(
      .easeOut(duration: Metric.duration),
      value: store.listInteraction.isSearching
    )
  }

}

private extension FestivalListView {
  var trimmedQuery: String {
    return store.listInteraction.trimmedQuery
  }

  var festivals: [FestivalOverview] {
    return store.festivals
  }

  var filterBinding: Binding<Int> {
    return Binding(
      get: { store.listInteraction.selectedFilter.rawValue },
      set: { send(.listFilterChanged(FestivalListInteractionState.Filter(rawValue: $0) ?? .all)) }
    )
  }

  var queryBinding: Binding<String> {
    return Binding(
      get: { store.listInteraction.query },
      set: { send(.searchQueryChanged($0)) }
    )
  }

  var hasCatalogFailure: Bool {
    return store.catalogCacheReadFailed || store.catalogRefreshFailed
  }

  var offlineMessage: String? {
    if store.catalogCacheReadFailed {
      return "저장된 페스티벌 목록을 읽지 못했습니다 · 연결 후 다시 시도해 주세요"
    }
    if store.catalogRefreshFailed {
      return festivals.isEmpty
        ? "페스티벌 목록을 불러오지 못했습니다 · 다시 시도해 주세요"
        : "최신 페스티벌 목록을 불러오지 못했습니다 · 저장된 목록을 표시합니다"
    }
    return nil
  }

  var visibleFestivals: [FestivalOverview] {
    return FestivalListPresentation.sorted(
      FestivalListPresentation.visible(
        festivals,
        query: "",
        bookedIDs: store.bookedFestivalIDs,
        onlyBooked: store.listInteraction.selectedFilter == .booked
      ),
      now: .now
    )
  }

  var searchResults: [FestivalOverview] {
    return FestivalListPresentation.sorted(
      FestivalListPresentation.visible(
        festivals,
        query: trimmedQuery,
        bookedIDs: store.bookedFestivalIDs,
        onlyBooked: false
      ),
      now: .now
    )
  }

  var artistResults: [FestivalListPresentation.ArtistSearchResult] {
    return FestivalListPresentation.matchingArtists(
      FestivalListPresentation.sorted(
      festivals,
      now: .now
    ),
      query: trimmedQuery
    )
  }

  var supportsArtistSearch: Bool {
    return festivals.contains { $0.artists != nil }
  }

  /// 목록을 좌우로 밀면 전체·예매 완료 탭을 바꾼다.
  var filterSwipe: some Gesture {
    return DragGesture(minimumDistance: Metric.swipeMinimumDistance)
      .onEnded { value in
        let horizontal = value.translation.width
        guard abs(horizontal) > Metric.swipeThreshold,
              abs(horizontal) > abs(value.translation.height) * Metric.swipeRatio
        else { return }
        send(.listFilterChanged(horizontal < 0 ? .booked : .all))
      }
  }

  @ViewBuilder
  func listContent() -> some View {
    Text(store.listInteraction.selectedFilter == .all ? Copy.allGuide : Copy.bookedGuide)
      .festiCoreFont(.baseSubheadlineMedium)
      .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    if store.viewState == .loading {
      FestivalListSkeletonView()
    } else if visibleFestivals.isEmpty {
      emptyCard()
    } else {
      ForEach(visibleFestivals) { festival in
        festivalCard(festival)
      }
      if store.listInteraction.selectedFilter == .all, let cursor = store.catalogNextCursor {
        if !store.catalogRefreshFailed {
          ProgressView()
            .frame(maxWidth: .infinity)
            .id(cursor)
            .onAppear { send(.loadMoreFestivals) }
        }
      }
    }
  }

  @ViewBuilder
  func emptyCard() -> some View {
    if festivals.isEmpty {
      FCEmptyCard(
        icon: .bell,
        title: "불러온 페스티벌이 없어요",
        message: hasCatalogFailure
          ? "연결을 확인하고 다시 시도해 주세요."
          : "새 페스티벌이 등록되면 여기에 표시해요."
      )
      .action(hasCatalogFailure ? FCCardAction(
        "다시 시도",
        action: { send(.refreshRequested) }
      ) : nil)
    } else {
      FCEmptyCard(
        icon: .bookmark20,
        title: "북마크한 페스티벌이 없어요",
        message: "예매한 페스티벌을 북마크하면 여기에 모아 볼 수 있어요."
      )
      .action(
        FCCardAction(
          "전체 보기",
          action: { send(.listFilterChanged(.all)) }
        )
      )
    }
  }

  func festivalCard(_ festival: FestivalOverview) -> some View {
    return FCFestivalCard(
      title: festival.name,
      meta: meta(for: festival),
      status: status(for: festival)
    ) {
      FestivalPosterView(
        url: store.state.imageURL(for: festival.thumbnailURL?.absoluteString),
        imageRevision: store.imageRevision
      )
    }
    .pack(pack(for: festival))
    .booked(
      store.bookedFestivalIDs.contains(festival.id),
      onToggle: { send(.toggleBookedFestival(festival.id)) }
    )
    .ticketLink { openTicketLink(festival) }
    .onTapGesture { send(.selectFestival(festival.id)) }
    .accessibilityIdentifier(FestivalAccessibilityID.card(festival.id))
  }

  @ViewBuilder
  func offlineBadge() -> some View {
    if let offlineMessage {
      FCOfflineBadge(offlineMessage)
    }
  }

  var searchBar: some View {
    return FCTopBar(.search(text: queryBinding))
      .searchPlaceholder(supportsArtistSearch ? "페스티벌, 아티스트, 장소 검색" : "페스티벌, 장소 검색")
      .onCancel {
        send(.searchClosed)
      }
      .onSubmit { saveRecentSearch() }
  }

  @ViewBuilder
  func searchContent() -> some View {
    if trimmedQuery.isEmpty {
      VStack(alignment: .leading, spacing: .zero) {
        if !store.recentSearches.isEmpty {
          FCSectionHeader("최근 검색")
            .action(
              "전체 삭제",
              perform: { send(.recentSearchesCleared) }
            )
            .padding(.top, FestiCoreSpacing.paddingP20)
            .padding(.bottom, FestiCoreSpacing.paddingP8)
            .padding(.horizontal, FestiCoreSpacing.paddingP16)
          FCFlowLayout {
            ForEach(
              store.recentSearches,
              id: \.self
            ) { keyword in
              FCRecentKeyword(
                keyword,
                onSelect: { send(.searchQueryChanged(keyword)) },
                onDelete: { send(.recentSearchRemoved(keyword)) }
              )
            }
          }
          .spacing(FestiCoreSpacing.paddingP8)
          .padding(.horizontal, FestiCoreSpacing.paddingP16)
        }
      }
    } else if store.viewState == .loading {
      searchSkeleton
    } else if festivals.isEmpty && hasCatalogFailure {
      FCEmptyCard(
        icon: .bell,
        title: "페스티벌을 불러오지 못했어요",
        message: "연결을 확인하고 다시 시도해 주세요."
      )
      .action(FCCardAction(
        "다시 시도",
        action: { send(.refreshRequested) }
      ))
      .padding(FestiCoreSpacing.paddingP16)
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
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
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
    return LazyVStack(spacing: .zero) {
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
            send(.selectFestival(festival.id))
          }
        )
        .highlightedQuery(trimmedQuery)
        .badgeStyle(badgeStyle(for: festival))
        .thumbnail(
          FestivalPosterView(
            url: store.state.imageURL(for: festival.thumbnailURL?.absoluteString),
            imageRevision: store.imageRevision
          )
        )
      }
    }
  }

  var artistResultRows: some View {
    return LazyVStack(spacing: .zero) {
      ForEach(artistResults) { result in
        FCSearchResultRow(
          .artist(initial: String(result.artist.name.prefix(1))),
          title: result.artist.name,
          meta: FestivalListPresentation.artistMeta(result, now: .now),
          action: {
            saveRecentSearch()
            send(.selectFestival(result.festival.id))
          }
        )
        .highlightedQuery(trimmedQuery)
      }
    }
  }

  func saveRecentSearch() {
    guard !trimmedQuery.isEmpty else { return }
    send(.recentSearchSubmitted(trimmedQuery))
  }

  func openTicketLink(_ festival: FestivalOverview) {
    if let url = festival.ticketURL {
      UIApplication.shared.open(url)
    } else {
      send(.ticketLinkMissing)
    }
  }

  func status(for festival: FestivalOverview) -> FCFestivalCard<FestivalPosterView>.Status {
    return switch FestivalListPresentation.cardStatus(
      for: festival,
      now: .now
    ) {
    case let .dDay(label): .dDay(label)
    case let .closing(label): .closing(label)
    case .upcoming: .upcoming()
    case .ended: .ended()
    }
  }

  func pack(for festival: FestivalOverview) -> FCFestivalCard<FestivalPosterView>.Pack {
    if case let .some(.downloading(progress)) = store.packDownloads[festival.id] {
      let fraction = progress.flatMap { value -> Double? in
        guard value.totalBytes > 0 else { return nil }
        return min(max(Double(value.receivedBytes) / Double(value.totalBytes), 0), 1)
      }
      let text = fraction.map { "팩 받는 중 · \(Int(($0 * 100).rounded()))%" } ?? "팩 받는 중"
      return .downloading(progress: fraction, text: text)
    }
    let copy = FestivalListPresentation.packCopy(for: festival)
    return switch copy {
    case let .unavailable(text): .unavailable(text)
    case let .ready(title): .ready(
      title: title,
      action: { send(.downloadPack(festival.id)) }
    )
    case let .received(text): .received(text)
    }
  }

  func badgeStyle(for festival: FestivalOverview) -> FCSearchResultRow.BadgeStyle {
    return switch FestivalListPresentation.cardStatus(
      for: festival,
      now: .now
    ) {
    case .closing: .closing
    case .upcoming: .upcoming
    case .dDay, .ended: .day
    }
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
