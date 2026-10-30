//
//  FCDoneHero.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 완료 화면 상단의 라임 체크와 제목·설명
public struct FCDoneHero: View {
  private var title: String
  private var message: String

  public init(
    title: String,
    message: String
  ) {
    self.title = title
    self.message = message
  }

  public var body: some View {
    VStack(spacing: FestiCoreSpacing.paddingP20) {
      FCCheckBadge()
      VStack(spacing: FestiCoreSpacing.paddingP8) {
        Text(title)
          .festiCoreFont(.baseTitle2Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .accessibilityAddTraits(.isHeader)
        Text(message)
          .festiCoreFont(.baseCalloutRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
    }
  }
}

#Preview {
  FCDoneHero(
    title: "깃발이 준비됐어요",
    message: "공연 당일 기수 보드에서 깃발을 올리면\n팔로워에게 알림이 가요."
  )
  .padding(FestiCoreSpacing.paddingP16)
}
