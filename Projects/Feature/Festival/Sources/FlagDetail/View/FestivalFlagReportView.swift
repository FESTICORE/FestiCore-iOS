//
//  FestivalFlagReportView.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import SwiftUI

/// Figma S05 E 신고 사유 선택 시트. 문구와 선택 표시는 SharedUI `FCReportSheet`가 그린다.
@ViewAction(for: FestivalFlagReportFeature.self)
public struct FestivalFlagReportView: View {
  @Bindable public var store: StoreOf<FestivalFlagReportFeature>

  public init(store: StoreOf<FestivalFlagReportFeature>) {
    self.store = store
  }

  public var body: some View {
    FCReportSheet(
      selection: selection,
      options: Self.reasons.map(title),
      onSubmit: { _ in send(.submitTapped) }
    )
  }
}

private extension FestivalFlagReportView {
  static let reasons = FestivalFlagReportReason.allCases

  /// 시트의 선택 위치를 신고 사유로 바꿔 보낸다.
  var selection: Binding<Int?> {
    return Binding(
      get: { store.selectedReason.flatMap(Self.reasons.firstIndex(of:)) },
      set: { index in
        guard let index else { return }
        send(.reasonSelected(Self.reasons[index]))
      }
    )
  }

  func title(_ reason: FestivalFlagReportReason) -> String {
    switch reason {
    case .fake: return "가짜 깃발이에요"
    case .inappropriate: return "부적절한 사진이나 소개예요"
    case .other: return "기타"
    }
  }
}

#Preview {
  FestivalFlagReportView(store: Store(initialState: FestivalFlagReportFeature.State()) {
    FestivalFlagReportFeature()
  })
  .preferredColorScheme(.dark)
}
