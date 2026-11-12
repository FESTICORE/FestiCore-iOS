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
  private(set) var showsFollow = true
  private(set) var showsZone = true
  private(set) var onZoneTap: () -> Void = {}
  private(set) var onTap: (() -> Void)?

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
            .festiCoreFont(.baseHeadlineBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .lineLimit(1)
          if let status {
            FCStatusChip(status)
          }
        }
        .figmaLineBox(
          .baseHeadlineBold,
          isEnabled: isDirectory
        )
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
            .figmaLineBox(
              .baseFootnoteRegular,
              isEnabled: true
            )
          HStack(spacing: FestiCoreSpacing.paddingP4) {
            ForEach(tags, id: \.self) { tag in
              FCTag(tag)
            }
          }
          if showsZone {
            FCZoneChip(
              zone,
              action: onZoneTap
            )
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if case let .directory(_, _, isFollowing, onFollow) = context {
        if showsFollow {
          FCButton(
            isFollowing ? "팔로잉" : "팔로우",
            action: onFollow
          )
          .style(Self.followStyle(isFollowing: isFollowing))
          .size(.medium)
          .isEnabled(isFollowEnabled)
        }
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundElevated.color, in: shape)
    .overlay { shape.strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: 1) }
    .cardTapAction(
      onTap,
      shape: shape
    )
  }
}

private extension FCFlagCard {
  var isDirectory: Bool {
    if case .directory = context { return true }
    return false
  }
}

private extension View {
  /// 카드 탭 동작이 있을 때만 카드 전체를 누를 수 있게 하고 접근성 동작을 더한다.
  @ViewBuilder
  func cardTapAction(
    _ action: (() -> Void)?,
    shape: some Shape
  ) -> some View {
    if let action {
      contentShape(shape)
        .onTapGesture(perform: action)
        .accessibilityAction(
          named: Text("깃발 상세 보기"),
          action
        )
    } else {
      self
    }
  }

  /// 깃발 디렉토리(S04) 텍스트에만 Figma 줄 높이 박스처럼 위아래 절반 여백을 둔다.
  func figmaLineBox(
    _ style: FestiCoreTextStyle,
    isEnabled: Bool
  ) -> some View {
    return padding(
      .vertical,
      isEnabled ? style.resolvedLineSpacing / 2 : .zero
    )
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

  /// 디렉토리 카드의 팔로우 버튼 표시 여부를 바꾼 사본을 돌려준다. Figma S10-E 미리보기는 버튼을 숨긴다.
  func showsFollow(_ isVisible: Bool) -> Self {
    var copy = self
    copy.showsFollow = isVisible
    return copy
  }

  /// 디렉토리 카드의 존 칩 표시 여부를 바꾼 사본을 돌려준다. Figma S04-E 오프라인은 존 칩을 숨긴다.
  func showsZone(_ isVisible: Bool) -> Self {
    var copy = self
    copy.showsZone = isVisible
    return copy
  }

  /// 존 칩을 눌렀을 때 동작을 바꾼 사본을 돌려준다.
  func onZoneTap(_ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.onZoneTap = action
    return copy
  }

  /// 카드 빈 곳을 눌렀을 때 동작(상세 열기)을 지정한 사본을 돌려준다. 팔로우·존 버튼은 각자 동작한다.
  func onTap(_ action: @escaping () -> Void) -> Self {
    var copy = self
    copy.onTap = action
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
