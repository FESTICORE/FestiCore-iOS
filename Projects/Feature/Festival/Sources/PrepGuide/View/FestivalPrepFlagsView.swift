//
//  FestivalPrepFlagsView.swift
//  Festival
//
//  Created by FestiCore on 11/9/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomainInterface
import SwiftUI

/// Figma S15-② 준비 안내 · 깃발 팔로우. 구성은 내 일정 고르기(S15-①)와 같다.
@ViewAction(for: FestivalPrepFlagsFeature.self)
public struct FestivalPrepFlagsView: View {
  @Bindable public var store: StoreOf<FestivalPrepFlagsFeature>

  public init(store: StoreOf<FestivalPrepFlagsFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCStepHeader(step: 2)
        .onLater { send(.laterTapped) }
      ScrollView {
        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.paddingP20
        ) {
          header
          filterChips
          content
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollIndicators(.hidden)
      bottomBar
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .onAppear { send(.onAppear) }
    .onDisappear { send(.onDisappear) }
  }
}

private extension FestivalPrepFlagsView {
  var header: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      Text("Step 2. 깃발 팔로우 하기")
        .festiCoreFont(.baseCaption1Medium)
        .festiCoreLineBox(.baseCaption1Medium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      Text("만나보고 싶은 깃발이 있나요?")
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text("팔로우 하면 깃발이 움직일 때 조용히 알려 드려요.\n없어도 공연은 그대로 즐길 수 있어요.")
        .festiCoreFont(.baseSubheadlineRegular)
        .festiCoreLineBox(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  /// 칩 줄은 화면 오른쪽 끝까지 스크롤된다(깃발 탭과 같다).
  var filterChips: some View {
    return ScrollView(.horizontal) {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        FCChip("전체") { send(.tagSelected(nil)) }
          .isSelected(store.flag.directory.tag == nil)
        ForEach(
          FestivalFlagDirectory.Tag.allCases,
          id: \.self
        ) { tag in
          FCChip(tag.title) { send(.tagSelected(tag)) }
            .isSelected(store.flag.directory.tag == tag)
        }
      }
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP16
      )
    }
    .scrollIndicators(.hidden)
    .padding(
      .horizontal,
      -FestiCoreSpacing.paddingP16
    )
  }

  @ViewBuilder
  var content: some View {
    if let snapshot = store.flag.snapshot {
      let rows = store.flag.directory.rows(
        in: snapshot,
        isFailed: store.flag.viewState != .loaded
      )
      VStack(
        alignment: .trailing,
        spacing: FestiCoreSpacing.paddingP12
      ) {
        Text("\(store.followingCount)개 팔로우")
          .festiCoreFont(.baseFootnoteBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        if rows.isEmpty {
          FCEmptyCard(
            title: snapshot.directoryFlags.isEmpty ? "아직 깃발이 없어요" : "이 성향의 깃발이 아직 없어요",
            message: snapshot.directoryFlags.isEmpty ? "깃발이 생기면 깃발 탭에서 팔로우할 수 있어요." : "다른 성향을 골라 보세요."
          )
        } else {
          LazyVStack(spacing: FestiCoreSpacing.paddingP12) {
            ForEach(rows) { row in
              card(row)
            }
          }
        }
      }
    } else if store.flag.viewState == .idle || store.flag.viewState == .loading {
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: Metric.skeletonHeight)
        .accessibilityLabel("깃발을 불러오는 중")
    } else {
      FCEmptyCard(
        title: "깃발을 불러오지 못했어요",
        message: "건너뛰고 나중에 깃발 탭에서 팔로우할 수 있어요."
      )
    }
  }

  func card(_ row: FestivalFlagDirectory.Row) -> some View {
    return FCFlagCard(
      name: row.name,
      status: nil,
      zone: row.zone,
      context: .directory(
        followers: row.followersText,
        tags: row.tags,
        isFollowing: row.isFollowing
      ) {
        send(.followTapped(
          id: row.id,
          follow: !row.isFollowing,
          baseCount: row.serverFollowerCount
        ))
      }
    ) {
      if let url = row.thumbnailURL {
        FCRemoteImage(url: url)
          .placeholderIcon(
            .flag20,
            size: 20
          )
      } else {
        FCThumbnail(nil)
      }
    }
    .followEnabled(row.isFollowEnabled)
  }

  var bottomBar: some View {
    let count = store.followingCount
    return HStack(spacing: FestiCoreSpacing.paddingP8) {
      FCButton("건너뛰기") { send(.skipTapped) }
        .style(.ghost)
      FCButton(count > 0 ? "다음 · \(count)개 팔로우" : "다음") { send(.nextTapped) }
        .isFullWidth(true)
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .top,
      FestiCoreSpacing.paddingP12
    )
    .padding(
      .bottom,
      FestiCoreSpacing.paddingP8
    )
    .overlay(alignment: .top) {
      FestiCoreSemanticColor.lineNormal.color.frame(height: Metric.divider)
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
  }

  enum Metric {
    static let skeletonHeight: CGFloat = 136
    static let divider: CGFloat = 1
  }
}
