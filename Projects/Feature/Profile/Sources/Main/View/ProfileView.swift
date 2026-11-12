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
          if store.showsLoginPrompt {
            loginPrompt
          }
          if store.myFlag != nil {
            myFlagSection()
          } else if store.showsBearerPrompt {
            // Figma More 기수 카드: 코드 없이 깃발 프로필을 만드는 흐름(S14 D)으로 잇는다.
            FCBearerPrompt(sub: "깃발 프로필을 만들면 바로 기수로 시작해요") { send(.bearerTapped) }
          }

          receivedPacks
        }
        .padding(.horizontal, FestiCoreSpacing.paddingP16)
        .padding(.top, FestiCoreSpacing.paddingP8)
      }
      .scrollIndicators(.hidden)
      .fcScrollBottomInset()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .onAppear { send(.onAppear) }
  }
}

private extension ProfileView {
  /// Figma More: 오른쪽 위 Settings Button(gear 24)이 S13-0 설정 홈을 연다.
  var topBar: some View {
    return FCTopBar(
      .large,
      title: "마이"
    )
    .overlay(alignment: .trailing) {
      Button { send(.settingsTapped) } label: {
        Image(asset: .gear24)
          .resizable()
          .scaledToFit()
          .frame(
            width: Metric.settingsIconSize,
            height: Metric.settingsIconSize
          )
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .frame(
            width: Metric.settingsButtonSize,
            height: Metric.settingsButtonSize
          )
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("설정")
      // Figma More Settings Button(24)은 오른쪽 끝에서 16 안쪽이다. 누르는 영역 44의 남는 10을 빼 6을 둔다.
      .padding(
        .trailing,
        FestiCoreSpacing.marginM6
      )
    }
  }

  /// 로그인하지 않았을 때 맨 위에 두는 로그인 유도 카드.
  /// Figma More 마이 B: Login Card(위아래 20·좌우 16, 간격 12), 제목 Headline/Bold·설명 Footnote/Regular(간격 4)
  var loginPrompt: some View {
    return VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP12
    ) {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP4
      ) {
        Text("로그인하고 더 함께 즐겨요")
          .festiCoreFont(.baseHeadlineBold)
          .festiCoreLineBox(.baseHeadlineBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text("깃발 팔로우 · 크루 · 기수는 로그인이 필요해요. 타임테이블과 팩은 로그인 없이도 쓸 수 있어요.")
          .festiCoreFont(.baseFootnoteRegular)
          .festiCoreLineBox(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      // Figma More B: 카드 안 Apple·Google Login Button(329×52), 간격 12
      FCLoginButton(.apple) { send(.socialLoginTapped(.apple)) }
      FCLoginButton(.google) { send(.socialLoginTapped(.google)) }
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP16
    )
    .padding(
      .vertical,
      FestiCoreSpacing.paddingP20
    )
    .background {
      RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
        .fill(FestiCoreSemanticColor.backgroundElevated.color)
    }
  }

  /// Figma More D: '내 깃발'(오른쪽 '기수') 아래 깃발 줄·기수 보드 열기·다른 페스티벌 깃발 만들기
  @ViewBuilder
  func myFlagSection() -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      HStack {
        sectionTitle("내 깃발")
        Spacer()
        Text("기수")
          .festiCoreFont(.baseFootnoteRegular)
          .festiCoreLineBox(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP4
      )
      VStack(spacing: .zero) {
        if let flag = store.myFlag {
          FCPackRow(
            name: flag.profile.name,
            meta: store.myFlagMeta ?? ""
          ) {
            send(.myFlagTapped)
          }
          .overlay(alignment: .leading) {
            if let url = flag.profile.thumbnailURL ?? flag.profile.photoURL {
              FCRemoteImage(url: url)
                .frame(
                  width: Metric.packThumbnailSize,
                  height: Metric.packThumbnailSize
                )
                .clipShape(RoundedRectangle(cornerRadius: Metric.packThumbnailRadius))
                .padding(
                  .leading,
                  FestiCoreSpacing.paddingP16
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
          }
        }
        rowDivider
        FCListRow("기수 보드 열기") { send(.bearerBoardTapped) }
        rowDivider
        FCListRow("다른 페스티벌 깃발 만들기") { send(.otherFestivalFlagTapped) }
      }
      .background {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          .fill(FestiCoreSemanticColor.backgroundElevated.color)
      }
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
  }

  var receivedPacks: some View {
    VStack(spacing: FestiCoreSpacing.paddingP8) {
      HStack {
        sectionTitle("내가 받은 팩")
        Spacer()
        if store.packLoad == .loaded {
          Text("\(store.packs.count)개")
            .festiCoreFont(.baseFootnoteRegular)
            .festiCoreLineBox(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
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
          // Figma More C: Empty Card(ticket 24).
          // Figma More C: 빈 카드의 '페스티벌 둘러보기'(Button primary·M)가 S00 페스티벌 목록을 연다.
          FCEmptyCard(
            icon: .ticket24,
            title: "아직 받은 팩이 없어요",
            message: "페스티벌을 고르면 시간표 · 지도 · 가는 길을 오프라인으로 받아 둘 수 있어요."
          )
          .action(FCCardAction(
            "페스티벌 둘러보기",
            style: .primary
          ) {
            send(.browseFestivalsTapped)
          })
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
    if pack.hasUpdate, let count = store.packChangedSets[pack.id], count > 0 {
      return "새 버전이 있어요 · 시간표 \(count)개 변경"
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
    static let settingsIconSize: CGFloat = 24
    static let settingsButtonSize: CGFloat = 44
  }

  /// Figma More 그룹 제목: Pretendard Bold 13, 줄 높이 18
  func sectionTitle(_ title: String) -> some View {
    Text(title)
      .festiCoreFont(.baseFootnoteBold)
      .festiCoreLineBox(.baseFootnoteBold)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }

  var rowDivider: some View {
    FestiCoreSemanticColor.lineNormal.color
      .frame(height: 1)
      // Figma More Divider: 좌우 16 안쪽(345)
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP16
      )
  }
}
