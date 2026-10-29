//
//  FestiCoreBearerCTA.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 기수 보드에서 버튼 4개 대신 보이는 큰 행동 영역. start는 시작 전, restart는 오늘 종료 후(하루 1번)이다.
public struct FestiCoreBearerCTA: View {
  public enum State: Sendable {
    case start
    case restart
  }

  private var state: State
  private var action: () -> Void

  public init(_ state: State, action: @escaping () -> Void) {
    self.state = state
    self.action = action
  }

  public var body: some View {
    VStack(spacing: FestiCoreSpacing.paddingP16) {
      flagMark
      Text(state == .start ? "오늘 깃발을 올릴 준비가 됐나요?" : "오늘 깃발을 내렸어요")
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Spacer()
        .frame(height: FestiCoreSpacing.paddingP8)
      ctaButton
      Text(state == .start ? "올리면 팔로워에게 알림이 가요" : "오늘 1번 더 시작할 수 있어요")
        .festiCoreFont(.baseCalloutMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      if state == .restart {
        Text("종료하지 않아도 공연이 끝나고 2시간 뒤에 자동으로 내려가요")
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .frame(maxWidth: .infinity)
      }
    }
    .multilineTextAlignment(.center)
  }

  private var flagMark: some View {
    Image(asset: .flag)
      .resizable()
      .frame(width: Metric.flagIconSize, height: Metric.flagIconSize)
      .foregroundStyle(state == .start ? FestiCoreSemanticColor.staticInk.color : FestiCoreSemanticColor.labelNormal.color)
      .frame(width: Metric.flagMarkSize, height: Metric.flagMarkSize)
      .background(
        state == .start ? FestiCoreSemanticColor.accentPointLime.color : FestiCoreSemanticColor.backgroundElevated.color,
        in: Circle()
      )
      .overlay {
        if state == .restart {
          Circle().stroke(FestiCoreSemanticColor.lineNormal.color, lineWidth: Metric.borderWidth)
        }
      }
      .accessibilityHidden(true)
  }

  private var ctaButton: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r24)
    return Button(action: action) {
      Text(state == .start ? "깃발 올리기" : "다시 시작하기")
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(state == .start ? FestiCoreSemanticColor.staticInk.color : FestiCoreSemanticColor.inverseLabel.color)
        .lineLimit(1)
        .padding(.horizontal, FestiCoreSpacing.paddingP20)
        .frame(maxWidth: .infinity)
        .frame(height: Metric.ctaHeight)
        .background(
          state == .start ? FestiCoreSemanticColor.accentPointLime.color : FestiCoreSemanticColor.inverseBackground.color,
          in: shape
        )
        .contentShape(shape)
    }
    .buttonStyle(.plain)
  }
}

private extension FestiCoreBearerCTA {
  enum Metric {
    static let flagMarkSize: CGFloat = 96
    static let flagIconSize: CGFloat = 42
    static let ctaHeight: CGFloat = 72
    static let borderWidth: CGFloat = 1
  }
}

#Preview {
  HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP24) {
    FestiCoreBearerCTA(.start) {}
    FestiCoreBearerCTA(.restart) {}
  }
  .padding(FestiCoreSpacing.paddingP16)
  .background(FestiCoreSemanticColor.backgroundAlternative.color)
  .preferredColorScheme(.dark)
}
