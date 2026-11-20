//
//  FestivalLiveBoardOfficialNewsSection.swift
//  Festival
//
//  Created by FestiCore on 11/20/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import SwiftUI

/// 라이브 보드 `공식 인스타그램` 섹션. 서버가 받아 둔 최근 게시물을 가로 카드로 보이고, 탭하면 원본 게시물을 연다.
/// Figma에 이 섹션이 아직 없어 팔로우한 깃발 타일과 같은 카드 토큰을 쓴다.
@ViewAction(for: FestivalLiveBoardFeature.self)
struct FestivalLiveBoardOfficialNewsSection: View {
  let store: StoreOf<FestivalLiveBoardFeature>
  let now: Date

  var body: some View {
    if let news = store.visibleOfficialNews, news.isVisible {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP16
      ) {
        FCSectionHeader("공식 인스타그램")
        ScrollView(.horizontal) {
          HStack(
            alignment: .top,
            spacing: FestiCoreSpacing.paddingP12
          ) {
            ForEach(news.posts) { post in
              Button {
                send(.officialNewsPostTapped(post.permalink))
              } label: {
                FestivalLiveBoardOfficialNewsCard(
                  post: post,
                  now: now
                )
              }
              .buttonStyle(.plain)
            }
          }
          .padding(
            .trailing,
            FestiCoreSpacing.paddingP16
          )
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
      }
    }
  }
}

/// 공식 인스타그램 게시물 카드. 이미지가 없으면 캡션만 보인다.
private struct FestivalLiveBoardOfficialNewsCard: View {
  let post: FestivalOfficialNews.Post
  let now: Date

  var body: some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP8
    ) {
      thumbnail
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
      Text(post.caption ?? "새 게시물")
        .festiCoreFont(.baseFootnoteRegular)
        .festiCoreLineBox(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(2)
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
      Text(postedText)
        .festiCoreFont(.baseCaption1Regular)
        .festiCoreLineBox(.baseCaption1Regular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    }
    .padding(FestiCoreSpacing.paddingP12)
    .frame(
      width: 156,
      alignment: .topLeading
    )
    .background(
      FestiCoreSemanticColor.backgroundElevated.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    )
    .accessibilityElement(children: .combine)
    .accessibilityHint("인스타그램에서 게시물을 열어요")
  }
}

private extension FestivalLiveBoardOfficialNewsCard {
  @ViewBuilder
  var thumbnail: some View {
    if post.imageURL != nil {
      FCRemoteImage(url: post.imageURL)
        .placeholderIcon(
          .music24,
          size: 24
        )
    } else {
      Image(asset: .music24)
        .resizable()
        .frame(
          width: 24,
          height: 24
        )
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity
        )
        .background(FestiCoreSemanticColor.fillStrong.color)
        .accessibilityHidden(true)
    }
  }

  var postedText: String {
    return FestivalLiveBoardPresentation.relativeTime(
      post.postedAt,
      now: now
    ) ?? post.postedAt.formatted(.monthDayTime)
  }
}
