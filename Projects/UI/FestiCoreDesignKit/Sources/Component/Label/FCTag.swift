//
//  FCTag.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 작은 라벨. neutral은 정보·나, secondary는 약한 보라 강조, lime은 내 일정, warning은 주의, onImage는 사진 위에 쓴다.
public struct FCTag: View {
  public enum Tone: Sendable {
    case neutral
    case secondary
    case lime
    case warning
    case onImage
  }

  private var label: String
  private(set) var tone: Tone = .neutral

  public init(_ label: String) {
    self.label = label
  }

  public var body: some View {
    Text(label)
      .festiCoreFont(.baseCaption2Medium)
      .foregroundStyle(foregroundColor.color)
      .lineLimit(1)
      .padding(.vertical, FestiCoreSpacing.marginM2)
      .padding(.horizontal, FestiCoreSpacing.marginM6)
      .background(backgroundColor.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r4))
  }

  private var backgroundColor: FestiCoreSemanticColor {
    switch tone {
    case .neutral: return .fillNormal
    case .secondary: return .accentBackgroundPurple
    case .lime: return .staticLime
    case .warning: return .accentBackgroundOrange
    case .onImage: return .staticalphaWhite20
    }
  }

  private var foregroundColor: FestiCoreSemanticColor {
    switch tone {
    case .neutral: return .labelNeutral
    case .secondary: return .accentForegroundPurple
    case .lime: return .staticInk
    case .warning: return .accentForegroundOrange
    case .onImage: return .staticWhite
    }
  }
}

// MARK: - 체이닝 설정

public extension FCTag {
  /// 색 구성을 바꾼 사본을 돌려준다.
  func tone(_ tone: Tone) -> Self {
    var copy = self
    copy.tone = tone
    return copy
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP8) {
    FCTag("슬램")
    FCTag("슬램").tone(.secondary)
    FCTag("슬램").tone(.lime)
    FCTag("슬램").tone(.warning)
    FCTag("슬램").tone(.onImage)
      .padding(FestiCoreSpacing.paddingP4)
      .background(FestiCoreSemanticColor.staticalphaBlack80.color)
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
