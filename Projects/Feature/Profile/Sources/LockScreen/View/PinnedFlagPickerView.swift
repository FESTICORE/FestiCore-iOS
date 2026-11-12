//
//  PinnedFlagPickerView.swift
//  Profile
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// 잠금화면에 보일 깃발 고르기 바텀시트. 시안이 없어 설정 목록 줄(`FCListRow` 체크)로 그린다.
@ViewAction(for: PinnedFlagPickerFeature.self)
public struct PinnedFlagPickerView: View {
  public let store: StoreOf<PinnedFlagPickerFeature>

  public init(store: StoreOf<PinnedFlagPickerFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP16
    ) {
      Text("잠금화면에 보일 깃발")
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP20
        )
      ScrollView {
        VStack(
          alignment: .leading,
          spacing: .zero
        ) {
          FCListRow("고르지 않음(가장 최근 팔로우)") { send(.noneTapped) }
            .isSelected(store.selectedFlagID == nil)
          followedFlags()
        }
      }
    }
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP24
    )
    .onAppear { send(.onAppear) }
  }
}

private extension PinnedFlagPickerView {
  @ViewBuilder
  func followedFlags() -> some View {
    switch store.followedFlags {
    case .loading:
      FCSkeletonView(.round())
        .frame(height: 24)
        .padding(FestiCoreSpacing.paddingP20)
        .accessibilityLabel("팔로우한 깃발을 불러오는 중")
    case .failed:
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP12
      ) {
        message("팔로우한 깃발을 불러오지 못했어요.")
        FCButton("다시 시도") { send(.retryTapped) }
          .style(.secondary)
          .size(.medium)
      }
      .padding(FestiCoreSpacing.paddingP20)
    case let .loaded(flags) where flags.isEmpty:
      message("팔로우한 깃발이 없어요. 깃발을 팔로우하면 여기서 고를 수 있어요.")
        .padding(FestiCoreSpacing.paddingP20)
    case let .loaded(flags):
      ForEach(flags) { flag in
        FCListRow(flag.name) { send(.flagTapped(flag.flagID)) }
          .isSelected(store.selectedFlagID == flag.flagID)
      }
    }
  }

  func message(_ text: String) -> some View {
    return Text(text)
      .festiCoreFont(.baseBodyRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      .fixedSize(
        horizontal: false,
        vertical: true
      )
  }
}
