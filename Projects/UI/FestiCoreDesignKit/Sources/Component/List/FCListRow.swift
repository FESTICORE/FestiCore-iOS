//
//  FCListRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 설정형 한 줄. chevron(이동) · toggle(켜기/끄기) · value(값 표시)를 지원한다.
public struct FCListRow: View {
  private enum Accessory {
    case chevron(action: () -> Void)
    case toggle(Binding<Bool>)
  }

  private var label: String
  private var accessory: Accessory
  private(set) var value: String?

  /// 누르면 이동하는 줄. 오른쪽에 화살표를 표시한다.
  public init(
    _ label: String,
    action: @escaping () -> Void
  ) {
    self.label = label
    accessory = .chevron(action: action)
  }

  /// 켜기/끄기 줄. 오른쪽에 `FCToggle`을 표시한다.
  public init(
    _ label: String,
    isOn: Binding<Bool>
  ) {
    self.label = label
    accessory = .toggle(isOn)
  }

  public var body: some View {
    switch accessory {
    case let .chevron(action):
      Button(action: action) {
        content {
          if let value {
            Text(value)
              .festiCoreFont(.baseBodyRegular)
              .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
              .lineLimit(1)
          }
          Image(asset: .chevronRight16)
            .resizable()
            .frame(width: Metric.iconSize, height: Metric.iconSize)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    case let .toggle(isOn):
      content {
        FCToggle(
          isOn: isOn,
          accessibilityLabel: label
        )
      }
    }
  }

}

private extension FCListRow {
  func content(@ViewBuilder trailing: () -> some View) -> some View {
    HStack(spacing: FestiCoreSpacing.paddingP16) {
      Text(label)
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      trailing()
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .frame(height: Metric.height)
    .background(FestiCoreSemanticColor.backgroundElevated.color)
  }
}

// MARK: - 체이닝 설정

public extension FCListRow {
  /// 화살표 앞에 보이는 값을 바꾼 사본을 돌려준다. 토글 줄에서는 무시한다.
  func value(_ value: String?) -> Self {
    var copy = self
    copy.value = value
    return copy
  }
}

private extension FCListRow {
  enum Metric {
    static let height: CGFloat = 56
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  @Previewable
  @State var isOn = true

  VStack(spacing: FestiCoreSpacing.paddingP12) {
    FCListRow("항목") {}
    FCListRow(
      "항목",
      isOn: $isOn
    )
    FCListRow("항목") {}
      .value("값")
  }
  .padding(FestiCoreSpacing.paddingP16)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
