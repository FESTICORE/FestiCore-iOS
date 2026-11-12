//
//  LoginModalView.swift
//  Login
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// 로그인이 필요할 때 `presentFCSheet`로 띄우는 소셜 로그인 시트
@ViewAction(for: LoginFeature.self)
public struct LoginModalView: View {
  @Bindable public var store: StoreOf<LoginFeature>

  public init(store: StoreOf<LoginFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      sheetContent()
      if let message = store.visibleMessage {
        Text(message)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .padding(
            .bottom,
            16
          )
      }
    }
  }
}

private extension LoginModalView {
  enum Metric {
    static let markSize: CGFloat = 56
    static let iconSize: CGFloat = 24
  }

  /// 문맥별 마크와 문구, 소셜 로그인 버튼, 나중에 하기 버튼
  @ViewBuilder
  func sheetContent() -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP16) {
      Image(asset: store.context == .crew ? .users24 : .flag)
        .resizable()
        .frame(
          width: Metric.iconSize,
          height: Metric.iconSize
        )
        .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
        .frame(
          width: Metric.markSize,
          height: Metric.markSize
        )
        .background(
          FestiCoreSemanticColor.staticLime.color,
          in: Circle()
        )
        .accessibilityHidden(true)
      VStack(spacing: FestiCoreSpacing.paddingP8) {
        Text(copy.title)
          .festiCoreFont(.baseTitle3Bold)
          .festiCoreLineBox(.baseTitle3Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .accessibilityAddTraits(.isHeader)
        Text(copy.message)
          .festiCoreFont(.baseSubheadlineRegular)
          .festiCoreLineBox(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP20
      )
      LoginProviderButtons(
        spacing: FestiCoreSpacing.paddingP16
      ) { send(.signInTapped($0)) }
      .padding(
        .vertical,
        FestiCoreSpacing.paddingP8
      )
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP20
      )
      Button("나중에 할게요") { send(.closeTapped) }
        .festiCoreFont(.baseFootnoteMedium)
        .festiCoreLineBox(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .buttonStyle(.plain)
    }
    .padding(
      .top,
      FestiCoreSpacing.paddingP8
    )
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP20
    )
    .fixedSize(
      horizontal: false,
      vertical: true
    )
  }

  /// 로그인을 요청한 문맥에 맞춘 시트 문구
  var copy: (title: String, message: String) {
    switch store.context {
    case .profile:
      return (
        "계정 정보를 보려면 로그인이 필요해요",
        "로그인 후 프로필을 확인할 수 있어요."
      )
    case .flag, .follow:
      return (
        "깃발을 팔로우 하려면 로그인이 필요해요",
        "내 취향의 깃발을 팔로우하고,\n함께 페스티벌을 즐길 사람들과 크루를 만들어봐요."
      )
    case .crew:
      return (
        "크루와 함께 보려면 로그인이 필요해요",
        "크루원끼리 지금 어느 존에 있는지 서로 볼 수 있어요.\n공연과 타임테이블은 로그인 없이 그대로 쓸 수 있어요."
      )
    case .bookmark:
      return (
        "축제를 저장하려면 로그인이 필요해요",
        "로그인 후 선택한 축제를 저장할 수 있어요."
      )
    case .report:
      return (
        "깃발을 신고하려면 로그인이 필요해요",
        "로그인 후 문제가 있는 깃발을 신고할 수 있어요."
      )
    }
  }
}

#Preview {
  LoginModalView(store: Store(initialState: LoginFeature.State()) { LoginFeature() })
}
