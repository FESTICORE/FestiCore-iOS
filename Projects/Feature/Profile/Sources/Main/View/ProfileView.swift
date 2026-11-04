//
//  ProfileView.swift
//  Profile
//
//  Created by FestiCore on 10/30/26.
//

import AuthDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import SwiftUI

@ViewAction(for: ProfileFeature.self)
public struct ProfileView: View {
  @Bindable public var store: StoreOf<ProfileFeature>

  public init(store: StoreOf<ProfileFeature>) {
    self.store = store
  }

  public var body: some View {
    main
  }
}

extension ProfileView {
  private var main: some View {
    VStack(spacing: .zero) {
      topBar

      if !store.hasSession, let message = store.message, !message.isEmpty {
        Text(message)
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, FestiCoreSpacing.paddingP20)
          .accessibilityAddTraits(.updatesFrequently)
      }

      ScrollView {
        VStack(spacing: FestiCoreSpacing.paddingP24) {
          FCBearerPrompt { send(.bearerTapped) }
            .allowsHitTesting(store.isBearerNavigationAvailable)

          receivedPacks
          settings
          information

          if let appVersion {
            Text("FESTICORE v\(appVersion)")
              .festiCoreFont(.baseCaption1Regular)
              .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, FestiCoreSpacing.paddingP16)
        .padding(.top, FestiCoreSpacing.paddingP8)
        .padding(.bottom, FestiCoreSpacing.paddingP24)
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .onAppear { send(.onAppear) }
  }
}

private extension ProfileView {
  @ViewBuilder
  var topBar: some View {
    if store.isSearchAvailable {
      FCTopBar(.large, title: "마이")
        .trailingAction { send(.searchTapped) }
    } else {
      FCTopBar(.large, title: "마이")
    }
  }

  var receivedPacks: some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      HStack {
        sectionTitle("내가 받은 팩")
        Spacer()
        if store.packLoad == .loaded {
          sectionTitle("\(store.packs.count)개")
        }
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP4)

      VStack(spacing: .zero) {
        switch store.packLoad {
        case .idle, .loading:
          packSkeletonRow
        case .failed:
          packFailure
        case .loaded where store.packs.isEmpty:
          Text("받은 팩이 없습니다")
            .festiCoreFont(.baseBodyRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            .frame(maxWidth: .infinity, minHeight: 68)
        case .loaded:
          ForEach(store.packs) { pack in
            if pack.id != store.packs.first?.id {
              rowDivider
            }
            packRow(pack)
          }
        }
      }
      .background {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          .fill(FestiCoreSemanticColor.backgroundElevated.color)
      }
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
  }

  func packRow(_ pack: FestivalReceivedPack) -> some View {
    FCPackRow(name: pack.name, meta: packMeta(pack)) {
      send(.packTapped(pack.id))
    }
    .hasUpdate(pack.hasUpdate)
    // FCPackRow는 로컬 이미지만 받으므로 서버 썸네일은 같은 자리에 겹쳐 그린다.
    .overlay(alignment: .leading) {
      if let url = pack.thumbnailURL {
        FCRemoteImage(url: url)
          .frame(width: Metric.packThumbnailSize, height: Metric.packThumbnailSize)
          .clipShape(RoundedRectangle(cornerRadius: Metric.packThumbnailRadius))
          .padding(.leading, FestiCoreSpacing.paddingP16)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
  }

  var packSkeletonRow: some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      FCSkeletonView(.round())
        .frame(width: Metric.packThumbnailSize, height: Metric.packThumbnailSize)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r4))
          .frame(width: 140, height: 16)
        FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r4))
          .frame(width: 180, height: 12)
      }
      Spacer()
    }
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
  }

  var packFailure: some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      Text("받은 팩을 불러오지 못했어요")
        .festiCoreFont(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      FCButton("다시 시도") { send(.packsRetryTapped) }
        .style(.secondary)
        .size(.medium)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, FestiCoreSpacing.paddingP16)
  }

  /// 새 버전이 있으면 버전을, 아니면 마지막 확인 시각을 보여 준다.
  func packMeta(_ pack: FestivalReceivedPack) -> String {
    if pack.autoUpdateFailed, let latest = pack.latestPackVersion {
      return "새 버전을 받지 못했어요 · v\(latest)"
    }
    if pack.hasUpdate, let latest = pack.latestPackVersion {
      return "새 버전이 있어요 · v\(latest)"
    }
    guard let checkedAt = pack.checkedAt else { return "최신 버전 · v\(pack.packVersion)" }
    return "최신 버전 · \(checkedAt.formatted(.monthDayTime)) 확인"
  }

  enum Metric {
    static let packThumbnailSize: CGFloat = 44
    static let packThumbnailRadius: CGFloat = 12 * 44 / 56
  }

  var settings: some View {
    section("설정") {
      FCListRow("알림") { send(.notificationsTapped) }
      rowDivider
      FCListRow("잠금화면") { send(.lockScreenTapped) }
      rowDivider
      FCListRow("계정") {
        send(.accountTapped)
      }
      .value(store.profile?.user.nickname ?? (store.hasSession ? nil : "로그인"))
    }
  }

  var information: some View {
    section("정보") {
      FCListRow("공지사항") { send(.noticeTapped) }
      rowDivider
      FCListRow("이용약관") { send(.termsTapped) }
      rowDivider
      FCListRow("개인정보 처리방침") { send(.privacyTapped) }
    }
  }

  func sectionTitle(_ title: String) -> some View {
    Text(title)
      .festiCoreFont(.baseCaption1Medium)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }

  func section<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      sectionTitle(title)
        .padding(.horizontal, FestiCoreSpacing.paddingP4)
      VStack(spacing: .zero, content: content)
        .background {
          RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
            .fill(FestiCoreSemanticColor.backgroundElevated.color)
        }
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
  }

  var rowDivider: some View {
    FestiCoreSemanticColor.lineNormal.color
      .frame(height: 1)
      .padding(.leading, FestiCoreSpacing.paddingP16)
  }

  var appVersion: String? {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
  }
}
