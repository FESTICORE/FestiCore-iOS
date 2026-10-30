//
//  FCSearchField.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 검색 입력창. 입력 중에는 지우기 버튼을 보인다.
public struct FCSearchField: View {
  @Binding private var text: String
  private var placeholder: String
  private(set) var onSubmit: () -> Void = {}

  public init(
    text: Binding<String>,
    placeholder: String = "페스티벌, 아티스트, 장소 검색"
  ) {
    _text = text
    self.placeholder = placeholder
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      icon(.magnifyingGlass16)
        .accessibilityHidden(true)
      TextField(
        "",
        text: $text,
        prompt: Text(placeholder).foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      )
      .festiCoreFont(.baseCalloutRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      .submitLabel(.search)
      .onSubmit(onSubmit)
      .accessibilityLabel(placeholder)
      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          icon(.circleXmark)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("지우기")
      }
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP12)
    .frame(height: Metric.height)
    .background(FestiCoreSemanticColor.fillNormal.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
  }

}

private extension FCSearchField {
  func icon(_ asset: ImageAsset) -> some View {
    Image(asset: asset)
      .resizable()
      .frame(width: Metric.iconSize, height: Metric.iconSize)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }
}

// MARK: - 체이닝 설정

public extension FCSearchField {
  /// 키보드 검색 버튼을 눌렀을 때 실행할 동작을 바꾼 사본을 돌려준다.
  func onSubmit(_ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.onSubmit = action
    return copy
  }
}

private extension FCSearchField {
  enum Metric {
    static let height: CGFloat = 40
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  @Previewable
  @State var keyword = "펜타포트"

  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCSearchField(text: .constant(""))
    FCSearchField(text: $keyword)
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
