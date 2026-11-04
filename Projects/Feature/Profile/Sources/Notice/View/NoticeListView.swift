//
//  NoticeListView.swift
//  Profile
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreUtility
import NoticeDomainInterface
import SwiftUI

@ViewAction(for: NoticeListFeature.self)
public struct NoticeListView: View {
  @Bindable public var store: StoreOf<NoticeListFeature>

  public init(store: StoreOf<NoticeListFeature>) {
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
    .navigationDestination(
      item: $store.scope(state: \.destination?.detail, action: \.destination.detail)
    ) { detailStore in
      NoticeDetailView(store: detailStore)
        .toolbar(.hidden, for: .navigationBar)
    }
    .onAppear { send(.onAppear) }
  }
}

private extension NoticeListView {
  @ViewBuilder
  var content: some View {
    switch store.load {
    case .idle, .loading:
      loadingContent
    case .failed:
      messageContent("공지사항을 불러오지 못했어요", retry: true)
    case .loaded where store.notices.isEmpty:
      messageContent("등록된 공지사항이 없어요", retry: false)
    case .loaded:
      ScrollView {
        VStack(spacing: .zero) {
          ForEach(store.notices, id: \.id) { notice in
            if notice.id != store.notices.first?.id {
              FestiCoreSemanticColor.lineNormal.color
                .frame(height: 1)
                .padding(.leading, FestiCoreSpacing.paddingP16)
            }
            FCListRow(notice.title) { send(.noticeTapped(notice.id)) }
              .value(notice.publishedAt.formatted(.noticeDay))
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
        .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollIndicators(.hidden)
    }
  }

  var loadingContent: some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      ForEach(0..<4) { _ in
        FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
          .frame(height: 56)
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .accessibilityLabel("공지사항을 불러오는 중")
  }

  func messageContent(_ message: String, retry: Bool) -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      Text(message)
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      if retry {
        FCButton("다시 시도") { send(.retryTapped) }
          .style(.secondary)
          .size(.medium)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

}
