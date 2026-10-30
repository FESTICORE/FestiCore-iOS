//
//  FCToggle.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 켜기/끄기 스위치. 알림, 잠금화면 표시 같은 설정에 쓴다.
public struct FCToggle: View {
  @Binding private var isOn: Bool
  private var accessibilityLabel: String

  public init(
    isOn: Binding<Bool>,
    accessibilityLabel: String
  ) {
    _isOn = isOn
    self.accessibilityLabel = accessibilityLabel
  }

  public var body: some View {
    Toggle(accessibilityLabel, isOn: $isOn)
      .toggleStyle(Style(label: accessibilityLabel))
      .labelsHidden()
  }
}

private extension FCToggle {
  struct Style: ToggleStyle {
    let label: String

    func makeBody(configuration: Configuration) -> some View {
      Capsule()
        .fill(configuration.isOn ? FestiCoreSemanticColor.primaryNormal.color : FestiCoreSemanticColor.fillStrong.color)
        .frame(width: Metric.width, height: Metric.height)
        .overlay(alignment: configuration.isOn ? .trailing : .leading) {
          Circle()
            .fill(FestiCoreSemanticColor.staticWhite.color)
            .frame(width: Metric.knobSize, height: Metric.knobSize)
            .shadow(color: FestiCoreSemanticColor.staticBlack.color.opacity(Metric.shadowOpacity), radius: Metric.shadowRadius, y: Metric.shadowY)
            .padding(Metric.knobInset)
        }
        .contentShape(Capsule())
        .onTapGesture {
          withAnimation(.easeInOut(duration: Metric.animationDuration)) {
            configuration.isOn.toggle()
          }
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(configuration.isOn ? "켬" : "끔")
        .accessibilityAddTraits(.isToggle)
        .accessibilityAction { configuration.isOn.toggle() }
    }
  }

  enum Metric {
    static let width: CGFloat = 51
    static let height: CGFloat = 31
    static let knobSize: CGFloat = 27
    static let knobInset: CGFloat = 2
    static let shadowOpacity: Double = 0.15
    // Figma blur 4는 SwiftUI radius 2에 해당한다.
    static let shadowRadius: CGFloat = 2
    static let shadowY: CGFloat = 2
    static let animationDuration: Double = 0.2
  }
}

#Preview {
  @Previewable
  @State var isOn = true

  HStack(spacing: FestiCoreSpacing.paddingP16) {
    FCToggle(
      isOn: $isOn,
      accessibilityLabel: "알림"
    )
    FCToggle(
      isOn: .constant(false),
      accessibilityLabel: "잠금화면 표시"
    )
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
