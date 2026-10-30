//
//  FCConsentRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 약관·동의 한 줄. 필수/선택 태그를 붙이고, 전문이 있으면 오른쪽 화살표로 전문을 연다.
public struct FCConsentRow: View {
  private var label: String
  private var isChecked: Bool
  private var action: () -> Void
  private(set) var tag: String?
  private(set) var sub: String?
  private(set) var onDetail: (() -> Void)?

  public init(_ label: String, isChecked: Bool, action: @escaping () -> Void) {
    self.label = label
    self.isChecked = isChecked
    self.action = action
  }

  public var body: some View {
    HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP12) {
      Button(action: action) {
        HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP12) {
          Image(asset: .check)
            .resizable()
            .frame(width: Metric.iconSize, height: Metric.iconSize)
            .foregroundStyle(isChecked ? FestiCoreSemanticColor.labelNormal.color : FestiCoreSemanticColor.lineStrong.color)
            .frame(width: Metric.checkSize, height: Metric.checkSize)
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
            HStack(spacing: FestiCoreSpacing.paddingP8) {
              if let tag {
                FCTag(tag)
              }
              Text(label)
                .festiCoreFont(.baseCalloutRegular)
                .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let sub {
              Text(sub)
                .festiCoreFont(.baseCaption1Regular)
                .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
            }
          }
          .multilineTextAlignment(.leading)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(isChecked ? .isSelected : [])
      if let onDetail {
        Button(action: onDetail) {
          Image(asset: .chevronRight16)
            .resizable()
            .frame(width: Metric.iconSize, height: Metric.iconSize)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
            .frame(height: Metric.checkSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) 전문 보기")
      }
    }
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
  }
}

// MARK: - 체이닝 설정

public extension FCConsentRow {
  /// 라벨 앞 태그(필수·선택)를 바꾼 사본을 돌려준다.
  func tag(_ tag: String?) -> Self {
    var copy = self
    copy.tag = tag
    return copy
  }

  /// 라벨 아래 설명을 바꾼 사본을 돌려준다.
  func sub(_ sub: String?) -> Self {
    var copy = self
    copy.sub = sub
    return copy
  }

  /// 전문 보기 동작을 바꾼 사본을 돌려준다. 값이 있으면 오른쪽 화살표를 표시한다.
  func onDetail(_ action: (() -> Void)?) -> Self {
    var copy = self
    copy.onDetail = action
    return copy
  }
}

private extension FCConsentRow {
  enum Metric {
    static let checkSize: CGFloat = 24
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  VStack(spacing: 0) {
    FCConsentRow("서비스 이용약관", isChecked: true) {}
      .tag("필수")
      .onDetail {}
    FCConsentRow("마케팅 알림 받기", isChecked: false) {}
      .tag("선택")
      .sub("공연 10분 전 · 팔로우한 깃발 · 크루 소식")
  }
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
