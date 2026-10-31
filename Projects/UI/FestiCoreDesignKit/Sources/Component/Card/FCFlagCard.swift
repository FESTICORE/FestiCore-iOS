//
//  FCFlagCard.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 깃발 카드. board는 라이브 보드의 지금 활동, directory는 깃발 디렉토리의 팔로우·태그를 보인다.
public struct FCFlagCard<Thumbnail: View>: View {
  public enum Context {
    case board(activity: String, time: String)
    case directory(followers: String, tags: [String], isFollowing: Bool, onFollow: () -> Void)
  }

  private var name: String
  private var status: FCStatusChip.Status?
  private var zone: String
  private var context: Context
  private var thumbnail: Thumbnail
  private(set) var isFollowEnabled = true
  private(set) var onZoneTap: () -> Void = {}

  /// `status`가 nil이면 상태 칩을 숨긴다. `thumbnail`은 56×56 둥근 사각형으로 잘린다.
  public init(
    name: String,
    status: FCStatusChip.Status?,
    zone: String,
    context: Context,
    @ViewBuilder thumbnail: () -> Thumbnail
  ) {
    self.name = name
    self.status = status
    self.zone = zone
    self.context = context
    self.thumbnail = thumbnail()
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP16) {
      thumbnail
        .frame(width: Metric.thumbnailSize, height: Metric.thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          Text(name)
            .festiCoreFont(.baseBodyBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .lineLimit(1)
          if let status {
            FCStatusChip(status)
          }
        }
        switch context {
        case let .board(activity, time):
          HStack(spacing: FestiCoreSpacing.paddingP8) {
            FCZoneChip(
              zone,
              action: onZoneTap
            )
            Text(activity)
              .festiCoreFont(.baseFootnoteBold)
              .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            Text("· \(time)")
              .festiCoreFont(.baseFootnoteRegular)
              .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .lineLimit(1)
        case let .directory(followers, tags, _, _):
          Text(followers)
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          HStack(spacing: FestiCoreSpacing.paddingP4) {
            ForEach(tags, id: \.self) { tag in
              FCTag(tag)
            }
          }
          FCZoneChip(
            zone,
            action: onZoneTap
          )
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if case let .directory(_, _, isFollowing, onFollow) = context {
        FCButton(
          isFollowing ? "팔로잉" : "팔로우",
          action: onFollow
        )
        .style(Self.followStyle(isFollowing: isFollowing))
        .size(.medium)
        .isEnabled(isFollowEnabled)
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: shape)
    .overlay { shape.strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: 1) }
  }
}

// MARK: - 체이닝 설정

public extension FCFlagCard where Thumbnail == FCThumbnail {
  init(
    name: String,
    status: FCStatusChip.Status?,
    zone: String,
    context: Context
  ) {
    self.init(name: name, status: status, zone: zone, context: context) { FCThumbnail(nil) }
  }

  /// 깃발 사진을 바꾼 사본을 돌려준다.
  func image(_ image: Image?) -> Self {
    var copy = self
    copy.thumbnail = FCThumbnail(image)
    return copy
  }
}

public extension FCFlagCard {
  /// Figma Flag Card: 팔로우 전은 inverse, 팔로우 중은 secondary 버튼이다.
  static func followStyle(isFollowing: Bool) -> FCButton.Style {
    isFollowing ? .secondary : .inverse
  }

  /// 팔로우 버튼 사용 여부를 바꾼 사본을 돌려준다. 요청 중·오프라인에서 끈다.
  func followEnabled(_ isEnabled: Bool) -> Self {
    var copy = self
    copy.isFollowEnabled = isEnabled
    return copy
  }

  /// 존 칩을 눌렀을 때 동작을 바꾼 사본을 돌려준다.
  func onZoneTap(_ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.onZoneTap = action
    return copy
  }
}

private extension FCFlagCard {
  enum Metric {
    static var thumbnailSize: CGFloat { 56 }
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCFlagCard(
      name: "호락호락",
      status: .active,
      zone: "리벳 앞 왼쪽",
      context: .board(activity: "슬램", time: "4분 전")
    )
    FCFlagCard(
      name: "호락호락",
      status: .active,
      zone: "리벳 앞 왼쪽",
      context: .directory(followers: "팔로워 1,284", tags: ["슬램", "떼창", "초보 환영"], isFollowing: false) {}
    )
  }
  .padding(FestiCoreSpacing.paddingP16)
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
