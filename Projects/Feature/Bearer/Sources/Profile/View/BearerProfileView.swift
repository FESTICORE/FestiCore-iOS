//
//  BearerProfileView.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import PhotosUI
import SwiftUI

/// Figma S10 A~E 깃발 프로필 등록·수정과 저장 완료
@ViewAction(for: BearerProfileFeature.self)
public struct BearerProfileView: View {
  @Bindable public var store: StoreOf<BearerProfileFeature>
  @State private var isPhotoPickerPresented = false
  @State private var pickedItem: PhotosPickerItem?

  public init(store: StoreOf<BearerProfileFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
      if let profile = store.savedProfile {
        doneContent(profile)
      } else {
        formContent
      }
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .photosPicker(isPresented: $isPhotoPickerPresented, selection: $pickedItem, matching: .images)
    .onChange(of: pickedItem) { _, item in
      guard let item else { return }
      pickedItem = nil
      Task {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        send(.photoPicked(data))
      }
    }
    .fcAlert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    .onAppear { send(.onAppear) }
  }
}

extension BearerProfileView {
  private var formContent: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: "깃발 프로필")
        .onBack { send(.backTapped) }
      if store.isLoading {
        loadingContent
      } else {
        ScrollView {
          VStack(
            alignment: .leading,
            spacing: Metric.sectionSpacing
          ) {
            header
            photoSection
            FCTextField(text: Binding(get: { store.name }, set: { send(.nameChanged($0)) }), placeholder: "예) 호락호락")
              .label("깃발 이름")
              .maxLength(BearerProfileFeature.nameRange.upperBound)
              .helper("2~20자 · 이 페스티벌에서 하나뿐인 이름이어야 해요")
              .error(store.nameError)
            FCTextField(text: Binding(get: { store.bio }, set: { send(.bioChanged($0)) }), placeholder: "어떤 깃발인지 한 줄로 알려 주세요")
              .label("한 줄 소개 (선택)")
              .maxLength(BearerProfileFeature.bioLimit)
            tagSection
            if !store.zones.isEmpty {
              zoneSection
            }
            settingSection
            if let saveError = store.saveError {
              Text(saveError)
                .festiCoreFont(.baseFootnoteRegular)
                .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
            }
          }
          .padding(FestiCoreSpacing.paddingP16)
          // Figma S10 Contents 아래 여백 32 = 공통 16 + 16
          .padding(
            .bottom,
            FestiCoreSpacing.paddingP16
          )
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(
          edge: .bottom,
          spacing: .zero
        ) {
          actionBar {
            FCPrimaryButton(
              saveTitle,
              isEnabled: store.canSave
            ) {
              send(.saveTapped)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var loadingContent: some View {
    if store.loadFailed {
      VStack(spacing: FestiCoreSpacing.paddingP12) {
        Text("깃발 프로필을 불러오지 못했어요")
          .festiCoreFont(.baseBodyMedium)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        FCButton("다시 시도") { send(.retryTapped) }
          .style(.secondary)
          .size(.medium)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
        FCSkeletonView(.round()).frame(height: 64)
        FCSkeletonView(.round()).frame(width: 88, height: 88)
        FCSkeletonView(.round()).frame(height: 52)
        FCSkeletonView(.round()).frame(height: 52)
        Spacer()
      }
      .padding(FestiCoreSpacing.paddingP16)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM8) {
      Text(headerTitle)
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text("팔로워에게 보일 깃발 프로필이에요.\n언제든 고칠 수 있어요.")
        .festiCoreFont(.baseCalloutRegular)
        .festiCoreLineBox(.baseCalloutRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  private var photoSection: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM8) {
      FCPhotoPicker(photoState) {
        if store.isUploadingPhoto {
          send(.photoCancelTapped)
        } else {
          isPhotoPickerPresented = true
        }
      }
      .buttonTitle(hasRemotePhotoOnly ? "바꾸기" : nil)
      if case .failed(let message) = store.photoUpload {
        Text(message)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
      }
    }
  }

  private var tagSection: some View {
    VStack(
      alignment: .leading,
      spacing: Metric.groupSpacing
    ) {
      sectionLabel("성향 태그", count: "\(store.tags.count) / \(BearerProfileFeature.tagLimit)")
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: FestiCoreSpacing.marginM8) {
          ForEach(BearerFlagTag.allCases, id: \.self) { tag in
            FCChip(tag.title) { send(.tagTapped(tag)) }
              .isSelected(store.tags.contains(tag))
          }
        }
      }
      helper("1~3개 고르면 깃발 디렉토리 필터에 걸려요.")
    }
  }

  private var zoneSection: some View {
    VStack(
      alignment: .leading,
      spacing: Metric.groupSpacing
    ) {
      sectionLabel("주로 있는 존", count: nil)
      LazyVGrid(
        columns: [
          GridItem(
            .flexible(),
            spacing: FestiCoreSpacing.marginM8
          ),
          GridItem(.flexible()),
        ],
        spacing: Metric.groupSpacing
      ) {
        ForEach(store.zones) { zone in
          BearerZoneButton(name: zone.name, isSelected: store.homeZoneID == zone.id) {
            send(.zoneTapped(zone.id))
          }
        }
      }
      helper("당일 첫 상태를 올리기 전까지 이 존에 \"예정\"으로 보여요.")
    }
  }

  private var settingSection: some View {
    VStack(
      alignment: .leading,
      spacing: Metric.groupSpacing
    ) {
      sectionLabel("오늘 계획 · 함께하는 기수", count: nil)
      VStack(spacing: .zero) {
        FCListRow("오늘 계획") { send(.planTapped) }
          .value(store.plan.isEmpty ? "고르기" : "\(store.plan.count)개 선택")
        FCListRow("팔로워에게 오늘 계획 보여주기", isOn: Binding(
          get: { store.planVisible },
          set: { send(.planVisibleChanged($0)) }
        ))
        FCListRow("공동 기수 초대") { send(.inviteTapped) }
          .value(store.coBearerText)
      }
      // Figma S10 Card: 모서리 16 안에 행을 자르고 1pt 테두리를 두른다.
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      .overlay {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          .strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: 1)
      }
      helper("오늘 계획은 내 일정에서 고른 셋이 그대로 보여요.")
    }
  }

  private func doneContent(_ profile: BearerFlagProfile) -> some View {
    Group {
      // Figma S10-E: 내용(히어로·미리보기, 사이 40)을 위아래 24 여백 안에서 세로 가운데에 둔다.
      GeometryReader { proxy in
        ScrollView {
          VStack(
            alignment: .leading,
            spacing: Metric.doneSectionSpacing
          ) {
            FCDoneHero(
              title: "깃발이 준비됐어요",
              message: "공연 당일 기수 보드에서 깃발을 올리면\n팔로워에게 알림이 가요."
            )
            .frame(maxWidth: .infinity)
            VStack(
              alignment: .leading,
              spacing: FestiCoreSpacing.marginM12
            ) {
              Text("깃발 목록에서 이렇게 보여요")
                .festiCoreFont(.baseFootnoteBold)
                .festiCoreLineBox(.baseFootnoteBold)
                .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
              previewCard(profile)
            }
          }
          .padding(
            .horizontal,
            FestiCoreSpacing.paddingP16
          )
          .padding(
            .vertical,
            FestiCoreSpacing.paddingP24
          )
          .frame(
            minHeight: proxy.size.height,
            alignment: .center
          )
        }
      }
    }
    .safeAreaInset(
      edge: .bottom,
      spacing: .zero
    ) {
      actionBar {
        FCPrimaryButton("완료") { send(.doneTapped) }
        FCButton("공동 기수 초대하기") { send(.inviteTapped) }
          .style(.ghost)
          .isEnabled(!store.isInviting)
      }
    }
  }

  /// Figma S10 Bottom Bar: 글래스 배경, 버튼 사이 4, 위 12·아래 8
  private func actionBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    return VStack(spacing: FestiCoreSpacing.paddingP4) {
      content()
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
    .background {
      Rectangle()
        .fill(.ultraThinMaterial)
        .overlay(FestiCoreSemanticColor.materialGlass.color)
        .ignoresSafeArea(edges: .bottom)
    }
  }

  /// Figma S10 Preview: 깃발 목록과 같은 Flag Card(디렉토리)로 보여 준다.
  private func previewCard(_ profile: BearerFlagProfile) -> some View {
    let zone = store.zones.first { $0.id == profile.homeZoneID }
    return FCFlagCard(
      name: profile.name,
      status: .scheduled,
      zone: zone?.name ?? "",
      context: .directory(
        followers: "팔로워 \(profile.followerCount)",
        tags: profile.tags.map(\.title),
        isFollowing: false,
        onFollow: {}
      )
    ) {
      previewThumbnail
    }
    .showsZone(zone != nil)
    .allowsHitTesting(false)
  }

  @ViewBuilder
  private var previewThumbnail: some View {
    if let image = image(from: store.uploadedPhotoData) {
      image.resizable().scaledToFill()
    } else if let url = store.photoURL {
      FCRemoteImage(url: url)
    } else {
      FCThumbnail(nil)
    }
  }

  private func sectionLabel(_ title: String, count: String?) -> some View {
    HStack {
      Text(title)
        .festiCoreFont(.baseFootnoteBold)
        .festiCoreLineBox(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Spacer()
      if let count {
        Text(count)
          .festiCoreFont(.baseFootnoteRegular)
          .festiCoreLineBox(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .monospacedDigit()
      }
    }
  }

  /// Figma 안내 줄: 13pt, 줄 상자 18
  private func helper(_ text: String) -> some View {
    Text(text)
      .festiCoreFont(.baseFootnoteRegular)
      .festiCoreLineBox(.baseFootnoteRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }

  private var photoState: FCPhotoPicker.State {
    if case let .uploading(data, progress) = store.photoUpload, let image = image(from: data) {
      return .uploading(image: image, progress: progress)
    }
    if let image = image(from: store.uploadedPhotoData) {
      return .filled(image)
    }
    return .empty
  }

  /// 서버에 사진은 있지만 이 기기에서 고른 사진이 없을 때. 사진 칸은 비우고 버튼만 "바꾸기"로 둔다.
  private var hasRemotePhotoOnly: Bool {
    store.uploadedPhotoData == nil && store.photoURL != nil && !store.isUploadingPhoto
  }

  private var headerTitle: String {
    guard store.isNewBearer else { return "깃발 프로필을 고쳐요" }
    return "\(store.festivalName ?? "페스티벌") 기수가 됐어요"
  }

  private var saveTitle: String {
    if store.isUploadingPhoto { return "사진 올리는 중이에요" }
    if store.isSaving { return "저장하는 중이에요" }
    return store.isNewBearer ? "등록하고 기수 시작하기" : "저장하기"
  }

  private func image(from data: Data?) -> Image? {
    guard let data, let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
  }

  private enum Metric {
    /// Figma S10 Contents 섹션 사이
    static let sectionSpacing: CGFloat = 28
    /// 라벨·내용·안내 사이(성향 태그·주로 있는 존·오늘 계획)
    static let groupSpacing: CGFloat = 12
    /// Figma S10-E 히어로와 미리보기 사이
    static let doneSectionSpacing: CGFloat = 40
  }
}

#Preview {
  BearerProfileView(store: .init(
    initialState: BearerProfileFeature.State(
      festivalID: "fst_preview",
      flagID: "flg_preview",
      profile: BearerFlagProfile(id: "flg_preview", name: "새 깃발 preview"),
      isNewBearer: true
    )
  ) {
    BearerProfileFeature()
  })
}
