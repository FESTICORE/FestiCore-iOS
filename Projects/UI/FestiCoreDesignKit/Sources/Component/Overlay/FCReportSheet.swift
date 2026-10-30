//
//  FCReportSheet.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 신고 사유 선택 바텀시트 내용. 사유를 고르기 전에는 신고 버튼이 비활성이다.
public struct FCReportSheet: View {
  @Binding private var selection: Int?
  private var options: [String]
  private var onSubmit: (Int) -> Void
  private(set) var title = "어떤 문제가 있나요?"
  private(set) var message = "신고는 익명으로 처리돼요"
  private(set) var submitTitle = "신고하기"

  public init(
    selection: Binding<Int?>,
    options: [String],
    onSubmit: @escaping (Int) -> Void
  ) {
    _selection = selection
    self.options = options
    self.onSubmit = onSubmit
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(title)
          .festiCoreFont(.baseTitle3Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .accessibilityAddTraits(.isHeader)
        Text(message)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      VStack(spacing: 0) {
        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
          Button {
            selection = index
          } label: {
            HStack(spacing: FestiCoreSpacing.paddingP12) {
              FCCheckCircle(isChecked: selection == index)
              Text(option)
                .festiCoreFont(.baseCalloutRegular)
                .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, FestiCoreSpacing.paddingP12)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(selection == index ? .isSelected : [])
        }
      }
      FCButton(submitTitle) {
        if let selection {
          onSubmit(selection)
        }
      }
      .isFullWidth(true)
      .isEnabled(selection != nil)
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP20)
  }
}

// MARK: - 체이닝 설정

public extension FCReportSheet {
  /// 제목·설명·버튼 글자를 바꾼 사본을 돌려준다.
  func texts(
    title: String,
    message: String,
    submitTitle: String
  ) -> Self {
    var copy = self
    copy.title = title
    copy.message = message
    copy.submitTitle = submitTitle
    return copy
  }
}

#Preview {
  @Previewable
  @State var selection: Int?

  FCReportSheet(
    selection: $selection,
    options: ["가짜 깃발이에요", "부적절한 사진이나 소개예요", "기타"],
    onSubmit: { _ in }
  )
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
