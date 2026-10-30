//
//  FCTextField.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 텍스트 입력(닉네임 등). 라벨·글자 수·도움말·오류 상태를 표시하고 입력 중에는 지우기 버튼을 보인다.
public struct FCTextField: View {
  @Binding private var text: String
  private var placeholder: String
  private(set) var label: String?
  private(set) var maxLength: Int?
  private(set) var helper: String?
  private(set) var error: String?
  @FocusState private var isFocused: Bool

  public init(text: Binding<String>, placeholder: String) {
    _text = text
    self.placeholder = placeholder
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      if let label {
        FCFieldLabel(label)
          .counter(maxLength.map { "\(text.count) / \($0)" })
      }
      field
      if let message = error ?? helper {
        Text(message)
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(error == nil ? FestiCoreSemanticColor.labelAssistive.color : FestiCoreSemanticColor.statusNegative.color)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .onChange(of: text) { _, newValue in
      if let maxLength, newValue.count > maxLength {
        text = String(newValue.prefix(maxLength))
      }
    }
  }

  private var field: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
    return HStack(spacing: FestiCoreSpacing.paddingP8) {
      TextField(
        "",
        text: $text,
        prompt: Text(placeholder).foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      )
      .festiCoreFont(.baseBodyRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      .focused($isFocused)
      .accessibilityLabel(label ?? placeholder)
      if isFocused, !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(asset: .circleXmark)
            .resizable()
            .frame(width: Metric.clearIconSize, height: Metric.clearIconSize)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("지우기")
      }
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .frame(height: Metric.height)
    .background(FestiCoreSemanticColor.fillNormal.color, in: shape)
    .overlay {
      if let borderColor {
        shape.strokeBorder(borderColor.color, lineWidth: Metric.borderWidth)
      }
    }
  }

  private var borderColor: FestiCoreSemanticColor? {
    if error != nil {
      return .statusNegative
    }
    return isFocused ? .labelNormal : nil
  }
}

// MARK: - 체이닝 설정

public extension FCTextField {
  /// 위 라벨을 바꾼 사본을 돌려준다.
  func label(_ label: String?) -> Self {
    var copy = self
    copy.label = label
    return copy
  }

  /// 최대 글자 수를 바꾼 사본을 돌려준다. 값이 있으면 라벨 오른쪽에 글자 수를 표시한다.
  func maxLength(_ maxLength: Int?) -> Self {
    var copy = self
    copy.maxLength = maxLength
    return copy
  }

  /// 아래 도움말을 바꾼 사본을 돌려준다.
  func helper(_ helper: String?) -> Self {
    var copy = self
    copy.helper = helper
    return copy
  }

  /// 오류 문구를 바꾼 사본을 돌려준다. 값이 있으면 도움말 대신 빨간 테두리와 문구를 표시한다.
  func error(_ error: String?) -> Self {
    var copy = self
    copy.error = error
    return copy
  }
}

private extension FCTextField {
  enum Metric {
    static let height: CGFloat = 52
    static let borderWidth: CGFloat = 1.5
    static let clearIconSize: CGFloat = 16
  }
}

#Preview {
  @Previewable
  @State var nickname = "민지"

  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCTextField(text: .constant(""), placeholder: "닉네임을 입력해 주세요")
      .label("닉네임")
      .maxLength(12)
      .helper("크루원과 깃발에 보이는 이름이에요. 나중에 마이에서 바꿀 수 있어요.")
    FCTextField(text: $nickname, placeholder: "닉네임을 입력해 주세요")
      .label("닉네임")
      .maxLength(12)
      .helper("크루원과 깃발에 보이는 이름이에요. 나중에 마이에서 바꿀 수 있어요.")
    FCTextField(text: $nickname, placeholder: "닉네임을 입력해 주세요")
      .label("닉네임")
      .maxLength(12)
      .error("이미 쓰고 있는 닉네임이에요. 다른 이름을 지어주세요.")
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
