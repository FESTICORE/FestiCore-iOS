//
//  FCAddItemRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 준비물에 내 항목을 추가하는 줄. 누르면 입력창과 추가 버튼으로 바뀐다.
public struct FCAddItemRow: View {
  @Binding private var text: String
  private var onAdd: () -> Void
  @State private var isTyping = false
  @FocusState private var isFocused: Bool

  public init(
    text: Binding<String>,
    onAdd: @escaping () -> Void
  ) {
    _text = text
    self.onAdd = onAdd
  }

  public var body: some View {
    HStack(spacing: Metric.spacing) {
      if isTyping {
        TextField("", text: $text)
          .festiCoreFont(.baseCalloutRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .focused($isFocused)
          .submitLabel(.done)
          .onSubmit(submit)
          .accessibilityLabel("내 항목")
          .padding(.horizontal, FestiCoreSpacing.paddingP12)
          .frame(height: Metric.inputHeight)
          .background(FestiCoreSemanticColor.fillNormal.color, in: RoundedRectangle(cornerRadius: Metric.inputRadius))
        FCButton(
          "추가",
          action: submit
        )
          .size(.medium)
          .isEnabled(!text.trimmingCharacters(in: .whitespaces).isEmpty)
      } else {
        Button {
          isTyping = true
          isFocused = true
        } label: {
          HStack(spacing: Metric.spacing) {
            Image(asset: .plus20)
              .resizable()
              .frame(width: Metric.iconSize, height: Metric.iconSize)
            Text("내 항목 추가")
              .festiCoreFont(.baseCalloutMedium)
          }
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .frame(height: Metric.height)
  }

}

private extension FCAddItemRow {
  func submit() {
    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    onAdd()
    isTyping = false
  }
}

private extension FCAddItemRow {
  enum Metric {
    static let height: CGFloat = 56
    static let spacing: CGFloat = 10
    static let iconSize: CGFloat = 20
    static let inputHeight: CGFloat = 40
    static let inputRadius: CGFloat = 10
  }
}

#Preview {
  @Previewable
  @State var item = "선크림"

  FCAddItemRow(text: $item) {}
    .background(FestiCoreSemanticColor.backgroundElevated.color)
}
