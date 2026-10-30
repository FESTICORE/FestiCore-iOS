//
//  FCLoginSheet.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 로그인 바텀시트 내용. 팔로우·크루·기수 진입 때만 `presentFCSheet`로 띄운다.
public struct FCLoginSheet: View {
  @Environment(\.fcSheetDismiss) private var dismiss
  private var title: String
  private var message: String
  private var onApple: () -> Void
  private var onGoogle: () -> Void
  private(set) var laterTitle = "나중에 할게요"

  public init(
    title: String,
    message: String,
    onApple: @escaping () -> Void,
    onGoogle: @escaping () -> Void
  ) {
    self.title = title
    self.message = message
    self.onApple = onApple
    self.onGoogle = onGoogle
  }

  public var body: some View {
    VStack(spacing: FestiCoreSpacing.paddingP16) {
      Image(asset: .flag)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
        .frame(width: Metric.markSize, height: Metric.markSize)
        .background(FestiCoreSemanticColor.staticLime.color, in: Circle())
        .accessibilityHidden(true)
      VStack(spacing: FestiCoreSpacing.paddingP8) {
        Text(title)
          .festiCoreFont(.baseTitle3Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .accessibilityAddTraits(.isHeader)
        Text(message)
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, FestiCoreSpacing.paddingP20)
      VStack(spacing: FestiCoreSpacing.paddingP16) {
        FCLoginButton(
          .apple,
          action: onApple
        )
        FCLoginButton(
          .google,
          action: onGoogle
        )
      }
      .padding(.vertical, FestiCoreSpacing.paddingP8)
      .padding(.horizontal, FestiCoreSpacing.paddingP20)
      Button(laterTitle, action: dismiss)
        .festiCoreFont(.baseFootnoteMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .buttonStyle(.plain)
    }
    .padding(.top, FestiCoreSpacing.paddingP8)
    .padding(.bottom, FestiCoreSpacing.paddingP20)
    .fixedSize(horizontal: false, vertical: true)
  }
}

// MARK: - 체이닝 설정

public extension FCLoginSheet {
  /// 아래 닫기 글자를 바꾼 사본을 돌려준다.
  func laterTitle(_ title: String) -> Self {
    var copy = self
    copy.laterTitle = title
    return copy
  }
}

private extension FCLoginSheet {
  enum Metric {
    static let markSize: CGFloat = 56
    static let iconSize: CGFloat = 24
  }
}

#Preview {
  FCLoginSheet(
    title: "깃발을 팔로우 하려면 로그인이 필요해요",
    message: "내 취향의 깃발을 팔로우하고, 함께 페스티벌을 즐길 사람들과 크루를 만들어봐요.",
    onApple: {},
    onGoogle: {}
  )
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
