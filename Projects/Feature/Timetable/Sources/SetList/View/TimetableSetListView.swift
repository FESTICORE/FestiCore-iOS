import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: TimetableSetListFeature.self)
public struct TimetableSetListView: View {
  public let store: StoreOf<TimetableSetListFeature>

  public init(store: StoreOf<TimetableSetListFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(
        .back,
        title: store.mode == .search ? "공연 검색" : "시간표 변경"
      )
        .onBack { send(.backTapped) }
      if store.mode == .search {
        FCSearchField(
          text: Binding(
            get: { store.query },
            set: { send(.queryChanged($0)) }
          ),
          placeholder: "아티스트, 무대 검색"
        )
        .padding(FestiCoreSpacing.paddingP16)
      }
      results()
      Spacer(minLength: .zero)
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
  }
}

private extension TimetableSetListView {
  @ViewBuilder
  func results() -> some View {
    if store.results.isEmpty {
      FCSearchEmpty(query: store.query)
        .message(store.mode == .changes ? "확인된 시간표 변경이 없어요" : "아티스트 이름이나 무대로 다시 찾아보세요")
    } else {
      ScrollView {
        LazyVStack(spacing: .zero) {
          ForEach(store.results) { day in
            ForEach(day.sets) { set in
              FCSearchResultRow(
                .artist(initial: String(set.artist.prefix(1))),
                title: set.artist,
                meta: "\(day.title) · \(set.timeRange)\(set.startChange.map { " · \($0)" } ?? "")",
                action: { send(.setTapped(set.id)) }
              )
            }
          }
        }
      }
      .fcScrollBottomInset()
    }
  }
}
