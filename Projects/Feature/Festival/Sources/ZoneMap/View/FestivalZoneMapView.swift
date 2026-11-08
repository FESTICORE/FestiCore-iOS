//
//  FestivalZoneMapView.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestivalDomainInterface
import SwiftUI

/// Figma S06 존 지도 A~J
@ViewAction(for: FestivalZoneMapFeature.self)
public struct FestivalZoneMapView: View {
  public let store: StoreOf<FestivalZoneMapFeature>
  @Dependency(\.date) private var date

  public init(store: StoreOf<FestivalZoneMapFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(
        .back,
        title: "존 지도"
      )
      .onBack { send(.backTapped) }
      if store.live.isOffline {
        FCOfflineBadge(FestivalLiveBoardPresentation.offlineText(
          receivedAt: store.live.receivedAt,
          deviceNow: date.now
        ))
      }
      content
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity
        )
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color.ignoresSafeArea())
    .onAppear { send(.onAppear) }
  }
}

private extension FestivalZoneMapView {
  @ViewBuilder
  var content: some View {
    switch store.map {
    case .loading:
      FestivalZoneMapSkeletonView()
    case .missing, .failed:
      unavailable
    case let .loaded(map):
      let model = FestivalZoneMapModel(
        map: map,
        snapshot: store.live.snapshot,
        viewerUserID: store.viewerUserID,
        now: date.now
      )
      if map.hasLayout {
        mapContent(
          map,
          model: model
        )
      } else {
        zoneList(
          map,
          model: model
        )
      }
    }
  }

  func mapContent(
    _ map: FestivalZoneMap,
    model: FestivalZoneMapModel
  ) -> some View {
    return GeometryReader { proxy in
      ScrollViewReader { reader in
        ScrollView {
          FestivalZoneMapCanvas(
            map: map,
            model: model,
            selectedZoneID: store.selectedZoneID,
            width: proxy.size.width,
            onZoneTap: { send(.zoneTapped($0)) },
            onBackgroundTap: { send(.mapBackgroundTapped) }
          )
          .padding(
            .vertical,
            Metric.mapVertical
          )
        }
        .scrollIndicators(.hidden)
        // 카드·범례가 차지한 만큼 지도를 더 올려 볼 수 있게 아래 여백으로 둔다.
        .safeAreaInset(
          edge: .bottom,
          spacing: .zero
        ) {
          bottomOverlay(
            map,
            model: model
          )
          .padding(FestiCoreSpacing.paddingP16)
        }
        .onAppear {
          reveal(
            store.selectedZoneID,
            reader: reader
          )
        }
        .onChange(of: store.selectedZoneID) { _, zoneID in
          withAnimation {
            reveal(
              zoneID,
              reader: reader
            )
          }
        }
      }
    }
    .overlay(alignment: .top) {
      if store.isMapChanged {
        FCBanner("지도가 바뀌었어요 · 팩을 업데이트해 주세요") { send(.updatePackTapped) }
          .icon(.triangleExclamation16)
          .padding(FestiCoreSpacing.paddingP16)
      }
    }
  }

  /// Figma S06 E. 고른 존이 카드에 가리면 카드 위로 보이도록 지도를 올린다.
  func reveal(
    _ zoneID: String?,
    reader: ScrollViewProxy
  ) {
    guard let zoneID else { return }
    reader.scrollTo(
      FestivalZoneMapCanvas.revealID(zoneID),
      anchor: .bottom
    )
  }

  @ViewBuilder
  func bottomOverlay(
    _ map: FestivalZoneMap,
    model: FestivalZoneMapModel
  ) -> some View {
    if let zone = map.zone(id: store.selectedZoneID) {
      FestivalZoneMapCard(card: FestivalZoneMapModel.card(
        zone: zone,
        map: map,
        snapshot: store.live.snapshot,
        viewerUserID: store.viewerUserID,
        now: date.now
      ))
    } else if let banner = model.bottomBanner {
      switch banner {
      case .followGuide:
        FCBanner("깃발을 팔로우하면 지도에 크게 보여요") { send(.followGuideTapped) }
          .icon(.triangleExclamation16)
      case .flagsDisabled:
        FCBanner("지금은 깃발 위치를 볼 수 없어요 · 크루만 보여요") {}
          .icon(.triangleExclamation16)
          .showsChevron(false)
      }
    } else {
      FestivalZoneMapLegend(
        showsFollowed: model.hasFollowedFlags,
        showsCrew: model.hasCrew,
        showsOther: model.flagsEnabled
      )
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
    }
  }

  func zoneList(
    _ map: FestivalZoneMap,
    model: FestivalZoneMapModel
  ) -> some View {
    return ScrollView {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP16
      ) {
        HStack(spacing: FestiCoreSpacing.marginM6) {
          Image(asset: .circleInfo16)
            .resizable()
            .frame(
              width: Metric.infoIcon,
              height: Metric.infoIcon
            )
            .accessibilityHidden(true)
          Text("이 페스티벌은 지도가 없어서 존 목록으로 보여 드려요.")
            .festiCoreFont(.baseFootnoteRegular)
            .festiCoreLineBox(.baseFootnoteRegular)
        }
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        FestivalZoneMapList(
          rows: map.zones.map { zone in
            return (
              id: zone.id,
              name: zone.name,
              value: model.countText(zone.id)
            )
          },
          onTap: { send(.zoneTapped($0)) }
        )
      }
      .padding(FestiCoreSpacing.paddingP16)
    }
  }

  var unavailable: some View {
    return VStack(spacing: FestiCoreSpacing.paddingP12) {
      Text(store.map == .missing ? "이 페스티벌 팩을 받으면 존 지도를 볼 수 있어요" : "존 지도를 불러오지 못했어요")
        .festiCoreFont(.baseBodyMedium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .multilineTextAlignment(.center)
      FCButton("다시 시도") { send(.retryTapped) }
        .style(.secondary)
        .size(.medium)
    }
    .padding(FestiCoreSpacing.paddingP16)
  }

  enum Metric {
    static let mapVertical: CGFloat = 16
    static let infoIcon: CGFloat = 16
  }
}

#Preview {
  FestivalZoneMapView(store: Store(initialState: FestivalZoneMapFeature.State(
    festivalID: "fst_preview",
    viewerUserID: nil
  )) {
    FestivalZoneMapFeature()
  })
}
