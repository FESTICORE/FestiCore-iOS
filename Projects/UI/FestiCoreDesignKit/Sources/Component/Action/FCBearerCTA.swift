//
//  FCBearerCTA.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 기수 보드에서 버튼 4개 대신 보이는 큰 행동 영역. start는 시작 전, restart는 오늘 종료 후(하루 1번)이다.
public struct FCBearerCTA: View {
  public enum State: Sendable {
    case start
    case restart
  }

  /// 화면에 보이는 문구. 바꾸지 않으면 상태별 Figma 기본 문구를 쓴다.
  public struct Copy: Sendable {
    public var title: String
    public var buttonTitle: String
    public var caption: String
    public var note: String?

    public init(
      title: String,
      buttonTitle: String,
      caption: String,
      note: String? = nil
    ) {
      self.title = title
      self.buttonTitle = buttonTitle
      self.caption = caption
      self.note = note
    }

    public static func defaultValue(for state: State) -> Copy {
      switch state {
      case .start:
        return Copy(
          title: "오늘 깃발을 올릴 준비가 됐나요?",
          buttonTitle: "깃발 올리기",
          caption: "올리면 팔로워에게 알림이 가요"
        )
      case .restart:
        return Copy(
          title: "오늘 깃발을 내렸어요",
          buttonTitle: "다시 시작하기",
          caption: "오늘 1번 더 시작할 수 있어요",
          note: "종료하지 않아도 공연이 끝나고 2시간 뒤에 자동으로 내려가요"
        )
      }
    }
  }

  private var state: State
  private var action: () -> Void
  private(set) var customCopy: Copy?

  public init(
    _ state: State,
    action: @escaping () -> Void
  ) {
    self.state = state
    self.action = action
  }

  public var body: some View {
    VStack(spacing: FestiCoreSpacing.paddingP16) {
      flagMark
      Text(copy.title)
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Spacer()
        .frame(height: FestiCoreSpacing.paddingP8)
      ctaButton
      Text(copy.caption)
        .festiCoreFont(.baseCalloutMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      if let note = copy.note {
        Text(note)
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

  private var copy: Copy {
    customCopy ?? .defaultValue(for: state)
  }

  private var ctaButton: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r24)
    return Button(action: action) {
      Text(copy.buttonTitle)
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

// MARK: - 체이닝 설정
public extension FCBearerCTA {
  /// 문구를 바꾼 사본을 돌려준다. `nil`이면 상태별 기본 문구를 쓴다.
  func copy(_ copy: Copy?) -> Self {
    var result = self
    result.customCopy = copy
    return result
  }
}

private extension FCBearerCTA {
  enum Metric {
    static let flagMarkSize: CGFloat = 96
    static let flagIconSize: CGFloat = 42
    static let ctaHeight: CGFloat = 72
    static let borderWidth: CGFloat = 1
  }
}

#Preview {
  HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP24) {
    FCBearerCTA(.start) {}
    FCBearerCTA(.restart) {}
  }
  .padding(FestiCoreSpacing.paddingP16)
  .background(FestiCoreSemanticColor.backgroundAlternative.color)
  .preferredColorScheme(.dark)
}
