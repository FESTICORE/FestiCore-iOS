//
//  FestivalFlagView.swift
//  Festival
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomainInterface
import SwiftUI

public struct FestivalFlagView: View {
  @Bindable private var store: StoreOf<FestivalFlagFeature>

  public init(store: StoreOf<FestivalFlagFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.large, title: "깃발")
      if store.viewState == .failed, let snapshot = store.snapshot {
        // 경과 시간 문구가 분 단위로 바뀌도록 1분마다 다시 그린다.
        TimelineView(.periodic(from: .now, by: Metric.offlineRefresh)) { context in
          FCOfflineBadge(FestivalFlagDirectory.offlineText(receivedAt: snapshot.receivedAt, now: context.date))
        }
      }
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
          head
          if store.festivalID == nil {
            FCEmptyCard(title: "축제를 선택해 주세요", message: "축제를 선택하면 해당 축제의 깃발을 볼 수 있습니다.")
          } else {
            filterChips
            content
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollIndicators(.hidden)
      .refreshable { store.send(.refresh) }
      .simultaneousGesture(
        TapGesture().onEnded { store.send(.directory(.sortMenuDismissed)) },
        isEnabled: store.directory.isSortMenuPresented
      )
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .overlay(alignment: .bottom) { toast }
    .onAppear { store.send(.appeared) }
    .onDisappear { store.send(.disappeared) }
  }
}

private extension FestivalFlagView {
  var head: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
      Text("만나보고 싶은 깃발이 있나요?")
        .festiCoreFont(.baseTitle3Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text("팔로우하지 않아도 괜찮아요. 깃발이 움직이면 조용히 알려 드려요.")
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  /// 칩 줄은 화면 오른쪽 끝까지 스크롤된다(Figma Filter Chips).
  var filterChips: some View {
    ScrollView(.horizontal) {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        FCChip("전체") { store.send(.directory(.tagSelected(nil))) }
          .isSelected(store.directory.tag == nil)
        ForEach(FestivalFlagDirectory.Tag.allCases, id: \.self) { tag in
          FCChip(tag.title) { store.send(.directory(.tagSelected(tag))) }
            .isSelected(store.directory.tag == tag)
        }
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
    }
    .scrollIndicators(.hidden)
    .padding(.horizontal, -FestiCoreSpacing.paddingP16)
  }

  @ViewBuilder
  var content: some View {
    if let snapshot = store.snapshot {
      switch store.viewState {
      case .deviceNotRegistered:
        FCEmptyCard(title: "기기 등록이 필요합니다", message: "앱을 다시 실행해 기기를 등록한 뒤 새로고침해 주세요. 이전 깃발을 표시합니다.")
      case .invalidFestivalID:
        FCEmptyCard(title: "축제 정보가 올바르지 않습니다", message: "앱을 업데이트한 뒤 다시 확인해 주세요. 이전 깃발을 표시합니다.")
      case .invalidResponse:
        FCEmptyCard(title: "깃발 정보 형식이 올바르지 않습니다", message: "문제가 계속되면 문의해 주세요. 이전 깃발을 표시합니다.")
      case .idle, .loading, .loaded, .failed:
        EmptyView()
      }
      flagList(snapshot)
    } else {
      switch store.viewState {
      case .idle, .loading:
        loadingContent
      case .failed:
        FCEmptyCard(title: "깃발을 불러오지 못했습니다", message: "네트워크 연결을 확인하고 아래로 당겨 다시 시도해 주세요.")
      case .deviceNotRegistered:
        FCEmptyCard(title: "기기 등록이 필요합니다", message: "앱을 다시 실행해 기기를 등록한 뒤 새로고침해 주세요.")
      case .invalidFestivalID:
        FCEmptyCard(title: "축제 정보가 올바르지 않습니다", message: "앱을 업데이트한 뒤 다시 확인해 주세요.")
      case .invalidResponse:
        FCEmptyCard(title: "깃발 정보 형식이 올바르지 않습니다", message: "문제가 계속되면 문의해 주세요.")
      case .loaded:
        FCEmptyCard(title: "깃발이 없습니다", message: "이 축제에 등록된 깃발이 없습니다.")
      }
    }
  }

  /// 이전 목록을 보이는 중에 새로고침이 실패했으면 팔로우를 막는다.
  var isRefreshFailed: Bool {
    switch store.viewState {
    case .failed, .deviceNotRegistered, .invalidFestivalID, .invalidResponse: true
    case .idle, .loading, .loaded: false
    }
  }

  func flagList(_ snapshot: FestivalLiveBoardSnapshot) -> some View {
    let rows = store.directory.rows(in: snapshot, isFailed: isRefreshFailed)
    return VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      HStack {
        Spacer(minLength: 0)
        FCSortButton(store.directory.sort.title) { store.send(.directory(.sortTapped)) }
      }
      .overlay(alignment: .topTrailing) { sortMenu }
      .zIndex(1)

      if rows.isEmpty {
        if snapshot.directoryFlags.isEmpty {
          FCEmptyCard(title: "깃발이 없습니다", message: "이 축제에 등록된 깃발이 없습니다.")
        } else {
          FCEmptyCard(title: "이 성향의 깃발이 아직 없어요", message: "다른 성향을 골라 보세요.")
        }
      } else {
        LazyVStack(spacing: FestiCoreSpacing.paddingP12) {
          ForEach(rows) { row in
            card(row)
          }
        }
      }
    }
  }

  /// Figma A-1: 정렬 버튼 아래 8pt에 오른쪽 끝을 맞춰 연다.
  @ViewBuilder
  var sortMenu: some View {
    if store.directory.isSortMenuPresented {
      FCSortMenu(
        selection: Binding(
          get: { FestivalFlagDirectory.Sort.allCases.firstIndex(of: store.directory.sort) ?? 0 },
          set: { store.send(.directory(.sortSelected(FestivalFlagDirectory.Sort.allCases[$0]))) }
        ),
        items: FestivalFlagDirectory.Sort.allCases.map(\.title)
      )
      .alignmentGuide(.top) { $0[.top] - Metric.sortButtonHeight - FestiCoreSpacing.paddingP8 }
      .transition(.opacity)
    }
  }

  func card(_ row: FestivalFlagDirectory.Row) -> some View {
    FCFlagCard(
      name: row.name,
      status: row.status.map(chipStatus),
      zone: row.zone,
      context: .directory(followers: row.followersText, tags: row.tags, isFollowing: row.isFollowing) {
        store.send(.directory(.followTapped(id: row.id, follow: !row.isFollowing, baseCount: row.serverFollowerCount)))
      }
    ) {
      if let url = row.thumbnailURL {
        FCRemoteImage(url: url)
      } else {
        FCThumbnail(nil)
      }
    }
    .followEnabled(row.isFollowEnabled)
  }

  func chipStatus(_ status: FestivalFlagDirectory.Status) -> FCStatusChip.Status {
    switch status {
    case .active: .active
    case .resting: .resting
    case .scheduled: .scheduled
    case .endedToday: .endedToday
    }
  }

  var loadingContent: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      ForEach(0 ..< 3, id: \.self) { _ in
        HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP16) {
          FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r12))
            .frame(width: Metric.thumbnailSize, height: Metric.thumbnailSize)
          VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
            FCSkeletonView(.round()).frame(width: 140, height: 20)
            FCSkeletonView(.round()).frame(width: 100, height: 16)
          }
          Spacer(minLength: 0)
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
    }
    .accessibilityLabel("깃발을 불러오는 중입니다")
  }

  var toast: some View {
    ZStack {
      if let message = store.directory.toast {
        FCToast(.init(icon: .circleInfo16, message: message))
          .padding(.bottom, FestiCoreSpacing.paddingP16)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.easeOut(duration: Metric.toastDuration), value: store.directory.toast)
  }
}

private extension FestivalFlagView {
  enum Metric {
    static let offlineRefresh: TimeInterval = 60
    static let thumbnailSize: CGFloat = 56
    /// Figma Sort Button 높이
    static let sortButtonHeight: CGFloat = 26
    static let toastDuration = 0.25
  }
}
