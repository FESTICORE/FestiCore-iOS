//
//  FCHeroFollowButton.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 사진 위 팔로우 버튼. follow는 흰 바탕, following은 글래스 바탕과 체크로 표시하며 모드와 관계없이 같다.
public struct FCHeroFollowButton: View {
  private var isFollowing: Bool
  private var action: () -> Void
  private(set) var followTitle = "팔로우"
  private(set) var followingTitle = "팔로잉"

  public init(
    isFollowing: Bool,
    action: @escaping () -> Void
  ) {
    self.isFollowing = isFollowing
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: FestiCoreSpacing.paddingP4) {
        if isFollowing {
          Image(asset: .check)
            .resizable()
            .frame(width: Metric.iconSize, height: Metric.iconSize)
        }
        Text(isFollowing ? followingTitle : followTitle)
          .festiCoreFont(.baseSubheadlineBold)
          .lineLimit(1)
      }
      .foregroundStyle(isFollowing ? FestiCoreSemanticColor.staticWhite.color : FestiCoreSemanticColor.staticInk.color)
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .frame(height: Metric.height)
      .background(
        isFollowing ? FestiCoreSemanticColor.staticalphaWhite20.color : FestiCoreSemanticColor.staticWhite.color,
        in: shape
      )
      .overlay {
        if isFollowing {
          shape.stroke(FestiCoreSemanticColor.staticalphaWhite40.color, lineWidth: Metric.borderWidth)
        }
      }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isFollowing ? .isSelected : [])
  }

}

private extension FCHeroFollowButton {
  var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: FestiCoreRadius.r8)
  }
}

// MARK: - 체이닝 설정

public extension FCHeroFollowButton {
  /// 팔로우 상태를 바꾼 사본을 돌려준다.
  func isFollowing(_ isFollowing: Bool) -> Self {
    var copy = self
    copy.isFollowing = isFollowing
    return copy
  }

  /// 상태별 글자를 바꾼 사본을 돌려준다.
  func titles(
    follow: String,
    following: String
  ) -> Self {
    var copy = self
    copy.followTitle = follow
    copy.followingTitle = following
    return copy
  }
}

private extension FCHeroFollowButton {
  enum Metric {
    static let height: CGFloat = 40
    static let iconSize: CGFloat = 16
    static let borderWidth: CGFloat = 1
  }
}

#Preview {
  HStack(spacing: FestiCoreSpacing.paddingP16) {
    FCHeroFollowButton(isFollowing: false) {}
    FCHeroFollowButton(isFollowing: true) {}
  }
  .padding(FestiCoreSpacing.paddingP20)
  .background(FestiCoreSemanticColor.staticalphaBlack80.color)
}
