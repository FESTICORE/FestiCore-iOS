//
//  FCLiveBadge.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 지금·다음 무대 표시. now는 Inverse, next는 Fill/Normal이다.
public struct FCLiveBadge: View {
  public enum Kind: Sendable {
    case now
    case next
  }

  private var kind: Kind

  public init(_ kind: Kind) {
    self.kind = kind
  }

  public var body: some View {
    Text(kind == .now ? "지금" : "다음")
      .festiCoreFont(.baseCaption1Bold)
      .foregroundStyle(kind == .now ? FestiCoreSemanticColor.inverseLabel.color : FestiCoreSemanticColor.labelNeutral.color)
      .padding(.vertical, FestiCoreSpacing.paddingP4)
      .padding(.horizontal, FestiCoreSpacing.marginM6)
      .background(
        kind == .now ? FestiCoreSemanticColor.inverseBackground.color : FestiCoreSemanticColor.fillNormal.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r8)
      )
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP12) {
    FCLiveBadge(.now)
    FCLiveBadge(.next)
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
