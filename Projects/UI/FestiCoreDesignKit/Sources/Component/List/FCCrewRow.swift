//
//  FCCrewRow.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 크루원 한 줄. 존·상태·N분 전을 표시하고, 60분이 넘은 정보는 회색으로 흐리게 보인다.
public struct FCCrewRow: View {
  private var name: String
  private var zone: String
  private var status: String
  private var time: String
  private(set) var avatarTint: FCAvatar.Tint = .gray
  private(set) var isMe = false
  private(set) var isStale = false
  private(set) var onZoneTap: () -> Void = {}

  public init(
    name: String,
    zone: String,
    status: String,
    time: String
  ) {
    self.name = name
    self.zone = zone
    self.status = status
    self.time = time
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP16) {
      FCAvatar(name)
        .tint(avatarTint)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        HStack(spacing: FestiCoreSpacing.paddingP4) {
          Text(name)
            .festiCoreFont(.baseCalloutBold)
            .foregroundStyle(primaryColor.color)
          if isMe {
            FCTag("나")
          }
        }
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          FCZoneChip(
            zone,
            action: onZoneTap
          )
          Text(status)
            .festiCoreFont(.baseFootnoteBold)
            .foregroundStyle(primaryColor.color)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
      Text(time)
        .festiCoreFont(.baseCaption1Regular)
        .foregroundStyle(isStale ? FestiCoreSemanticColor.labelDisable.color : FestiCoreSemanticColor.labelAssistive.color)
    }
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .opacity(isStale ? Metric.staleOpacity : 1)
  }

  private var primaryColor: FestiCoreSemanticColor {
    isStale ? .labelAssistive : .labelNormal
  }
}

// MARK: - 체이닝 설정

public extension FCCrewRow {
  /// 이니셜 색을 바꾼 사본을 돌려준다.
  func avatarTint(_ tint: FCAvatar.Tint) -> Self {
    var copy = self
    copy.avatarTint = tint
    return copy
  }

  /// 내 줄 여부를 바꾼 사본을 돌려준다. 이름 옆에 "나" 태그를 붙인다.
  func isMe(_ isMe: Bool) -> Self {
    var copy = self
    copy.isMe = isMe
    return copy
  }

  /// 오래된 정보 여부를 바꾼 사본을 돌려준다.
  func isStale(_ isStale: Bool) -> Self {
    var copy = self
    copy.isStale = isStale
    return copy
  }

  /// 존 칩을 눌렀을 때 동작을 바꾼 사본을 돌려준다.
  func onZoneTap(_ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.onZoneTap = action
    return copy
  }
}

private extension FCCrewRow {
  enum Metric {
    static let staleOpacity: Double = 0.6
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP12) {
    FCCrewRow(
      name: "민지",
      zone: "리벳 앞 왼쪽",
      status: "밥",
      time: "3분 전"
    )
    .isMe(true)
    FCCrewRow(
      name: "민지",
      zone: "리벳 앞 왼쪽",
      status: "밥",
      time: "1시간 전"
    )
    .isStale(true)
  }
  .padding(FestiCoreSpacing.paddingP16)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
