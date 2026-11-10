//
//  NoticeDetailView.swift
//  Profile
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreUtility
import NoticeDomainInterface
import SwiftUI

@ViewAction(for: NoticeDetailFeature.self)
public struct NoticeDetailView: View {
  public let store: StoreOf<NoticeDetailFeature>

  public init(store: StoreOf<NoticeDetailFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: "공지사항")
        .onBack { send(.backTapped) }
      content
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .toolbar(.hidden, for: .navigationBar)
    .onAppear { send(.onAppear) }
  }
}

private extension NoticeDetailView {
  @ViewBuilder
  var content: some View {
    switch store.load {
    case .idle, .loading:
      loadingContent()
    case .failed:
      messageContent()
    case .loaded:
      if let detail = store.detail {
        ScrollView {
          VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
            Text(detail.title)
              .festiCoreFont(.baseTitle3Bold)
              .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            Text(detail.publishedAt.formatted(.noticeDay))
              .festiCoreFont(.baseCaption1Regular)
              .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
            FestiCoreSemanticColor.lineNormal.color.frame(height: 1)
            Text(detail.content)
              .festiCoreFont(.baseBodyRegular)
              .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(
            .horizontal,
            FestiCoreSpacing.paddingP20
          )
          .padding(
            .top,
            FestiCoreSpacing.paddingP20
          )
        }
        .scrollIndicators(.hidden)
        .fcScrollBottomInset()
      }
    }
  }

  @ViewBuilder
  func loadingContent() -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r4))
        .frame(height: 24)
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r4))
        .frame(width: 90, height: 14)
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r4))
        .frame(height: 180)
    }
    .padding(FestiCoreSpacing.paddingP20)
    .accessibilityLabel("공지사항을 불러오는 중")
  }

  @ViewBuilder
  func messageContent() -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      Text("공지사항을 불러오지 못했어요")
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      FCButton("다시 시도") { send(.retryTapped) }
        .style(.secondary)
        .size(.medium)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
