import FestiCoreDesignKit
import SwiftUI

struct HomeFestivalListView: View {
  let festivals: [FestivalOverview]
  let selectedFestivalID: String?
  let bookedFestivalIDs: Set<String>
  let imageRevision: Int
  let imageURL: (String?) -> URL?
  let onSelect: (String) -> Void
  let onToggleBooked: (String) -> Void

  @State private var selectedFilter = 0
  @State private var isSearching = false
  @State private var query = ""

  private var visibleFestivals: [FestivalOverview] {
    FestivalListPresentation.visible(
      festivals, query: query, bookedIDs: bookedFestivalIDs, onlyBooked: selectedFilter == 1
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      HStack {
        Text("페스티벌")
          .font(.title2.bold())
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Spacer()
        Button {
          withAnimation { isSearching.toggle() }
          if !isSearching { query = "" }
        } label: {
          Image(systemName: isSearching ? "xmark" : "magnifyingglass")
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel(isSearching ? "검색 닫기" : "페스티벌 검색")
      }

      if isSearching {
        TextField("페스티벌 또는 장소 검색", text: $query)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .padding(FestiCoreSpacing.paddingP12)
          .background(FestiCoreSemanticColor.backgroundElevated.color,
                      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
          .accessibilityIdentifier("festivalSearchField")
      }

      HStack(spacing: 0) {
        filterTab("전체", index: 0)
        filterTab("예매 완료", index: 1)
      }

      Text(selectedFilter == 0
        ? "가고 싶은 페스티벌을 찾아보세요. 이미 예매한 페스티벌은 북마크해서 바로 확인할 수 있어요."
        : "북마크한 페스티벌을 모아 봅니다.")
        .font(.caption)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)

      if visibleFestivals.isEmpty {
        ContentUnavailableView(
          festivals.isEmpty ? "불러온 페스티벌이 없습니다" : "조건에 맞는 페스티벌이 없습니다",
          systemImage: "calendar",
          description: Text(festivals.isEmpty
            ? "연결되면 페스티벌 목록을 가져옵니다."
            : "검색어 또는 예매 완료 표시를 확인해 주세요.")
        )
      } else {
        ForEach(visibleFestivals) { festival in festivalCard(festival) }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func filterTab(_ title: String, index: Int) -> some View {
    Button { selectedFilter = index } label: {
      VStack(spacing: FestiCoreSpacing.paddingP8) {
        Text(title)
          .font(.subheadline.weight(selectedFilter == index ? .semibold : .regular))
          .foregroundStyle(selectedFilter == index
            ? FestiCoreSemanticColor.labelNormal.color
            : FestiCoreSemanticColor.labelAssistive.color)
        Rectangle()
          .fill(selectedFilter == index ? FestiCoreSemanticColor.labelNormal.color : Color.clear)
          .frame(height: 2)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selectedFilter == index ? .isSelected : [])
  }

  private func festivalCard(_ festival: FestivalOverview) -> some View {
    let status: FCFestivalCard<HomePosterView>.Status = switch FestivalListPresentation.timing(
      for: festival, now: .now
    ) {
    case let .daysUntil(days): .dDay("D-\(days)")
    case .live: .dDay("진행 중")
    case .ended: .ended("종료")
    case .undated: .upcoming("일정 확인")
    }
    let dates = [festival.firstDate, festival.lastDate].compactMap { $0 }.joined(separator: " – ")
    let meta = [festival.venue, dates.isEmpty ? nil : dates].compactMap { $0 }.joined(separator: " · ")

    return FCFestivalCard(title: festival.name, meta: meta, status: status) {
      HomePosterView(url: imageURL(festival.thumbnailURL?.absoluteString), imageRevision: imageRevision)
    }
    .pack(festival.isCached
      ? .received("오프라인 팩 저장됨")
      : festival.packVersion > 0
        ? .ready(action: { onSelect(festival.id) })
        : .unavailable("오프라인 팩 공개 전"))
    .booked(bookedFestivalIDs.contains(festival.id), onToggle: { onToggleBooked(festival.id) })
    .onTapGesture { onSelect(festival.id) }
    .accessibilityIdentifier("festivalCard_\(festival.id)")
    .overlay(alignment: .bottomTrailing) {
      if selectedFestivalID == festival.id {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .padding(FestiCoreSpacing.paddingP8)
          .accessibilityLabel("선택됨")
      }
    }
  }
}
