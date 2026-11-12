//
//  BearerRegisterView.swift
//  Bearer
//
//  Created by FestiCore on 11/12/26.
//

import BearerDomainInterface
import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import PhotosUI
import SwiftUI

/// Figma S14 D1·D2 깃발 프로필 등록(코드 없음)과 E1·E2 저장 완료
@ViewAction(for: BearerRegisterFeature.self)
public struct BearerRegisterView: View {
  @Bindable public var store: StoreOf<BearerRegisterFeature>
  @State private var isPhotoPickerPresented = false
  @State private var pickedItem: PhotosPickerItem?

  public init(store: StoreOf<BearerRegisterFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
      if let completion = store.completion {
        doneContent(completion)
      } else {
        formContent()
      }
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .photosPicker(
      isPresented: $isPhotoPickerPresented,
      selection: $pickedItem,
      matching: .images
    )
    .onChange(of: pickedItem) { _, item in
      guard let item else { return }
      pickedItem = nil
      Task {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        send(.photoPicked(data))
      }
    }
    .fcAlert($store.scope(
      state: \.destination?.alert,
      action: \.destination.alert
    ))
    .onAppear { send(.onAppear) }
  }
}

private extension BearerRegisterView {
  @ViewBuilder
  func formContent() -> some View {
    VStack(spacing: .zero) {
      FCTopBar(
        .back,
        title: "깃발 프로필"
      )
      .onBack { send(.backTapped) }
      ScrollView {
        VStack(
          alignment: .leading,
          spacing: Metric.sectionSpacing
        ) {
          header()
          festivalSection
          photoSection
          FCTextField(
            text: Binding(
              get: { store.form.name },
              set: { send(.nameChanged($0)) }
            ),
            placeholder: "예) 호락호락"
          )
          .label("깃발 이름")
          .maxLength(BearerProfileFeature.nameRange.upperBound)
          .helper("2~20자 · 이 페스티벌에서 하나뿐인 이름이어야 해요")
          .error(store.nameError)
          FCTextField(
            text: Binding(
              get: { store.form.bio },
              set: { send(.bioChanged($0)) }
            ),
            placeholder: "어떤 깃발인지 한 줄로 알려 주세요"
          )
          .label("한 줄 소개 (선택)")
          .maxLength(BearerProfileFeature.bioLimit)
          tagSection()
          if !store.zones.isEmpty {
            zoneSection()
          }
          settingSection()
          FCButton("공동 기수 초대 코드가 있어요") { send(.claimTapped) }
            .style(.ghost)
            .size(.medium)
            .isEnabled(store.selectedFestivalID != nil)
            .frame(maxWidth: .infinity)
          if let saveError = store.saveError {
            Text(saveError)
              .festiCoreFont(.baseFootnoteRegular)
              .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .scrollDismissesKeyboard(.interactively)
      .safeAreaInset(
        edge: .bottom,
        spacing: .zero
      ) {
        actionBar {
          FCPrimaryButton(
            store.isSaving ? "만드는 중이에요" : "등록하고 기수 시작하기",
            isEnabled: store.canSave
          ) {
            send(.saveTapped)
          }
          FCButton("나중에 할게요 · 마이에서 언제든 만들 수 있어요") { send(.laterTapped) }
            .style(.ghost)
            .size(.medium)
        }
      }
    }
  }

  @ViewBuilder
  func header() -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM8
    ) {
      Text("내 깃발을 만들어요")
        .festiCoreFont(.baseTitle2Bold)
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text("팔로워에게 보일 깃발 프로필이에요.\n지금 다 채우지 않아도 언제든 고칠 수 있어요.")
        .festiCoreFont(.baseCalloutRegular)
        .festiCoreLineBox(.baseCalloutRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  @ViewBuilder
  var festivalSection: some View {
    VStack(
      alignment: .leading,
      spacing: Metric.groupSpacing
    ) {
      sectionLabel(
        "어느 페스티벌의 깃발인가요?",
        count: nil
      )
      switch store.festivals.load {
      case .loading:
        ForEach(0 ..< BearerRegisterFeature.upcomingPreviewCount, id: \.self) { _ in
          FCSkeletonView(.round()).frame(height: 44)
        }

      case let .failed(offline):
        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.paddingP8
        ) {
          helper(offline
            ? "인터넷에 연결되지 않아 페스티벌을 불러오지 못했어요."
            : "깃발을 만들 수 있는 페스티벌을 불러오지 못했어요.")
          FCButton("다시 시도") { send(.retryTapped) }
            .style(.secondary)
            .size(.medium)
        }

      case .loaded:
        festivalRows
      }
    }
  }

  @ViewBuilder
  var festivalRows: some View {
    let hasReceived = !store.festivals.received.isEmpty
    if hasReceived {
      helper("내가 받은 팩")
      ForEach(store.festivals.received) { option in
        festivalButton(option)
      }
      if !store.festivals.visibleUpcoming.isEmpty {
        helper("다른 페스티벌")
      }
    }
    ForEach(store.festivals.visibleUpcoming) { option in
      festivalButton(option)
    }
    if store.festivals.canShowMore {
      FCButton("다른 페스티벌 찾기") { send(.showMoreTapped) }
        .style(.ghost)
        .frame(maxWidth: .infinity)
    }
    helper(hasReceived
      ? "로그인 전에 받은 팩·핀한 페스티벌이 먼저 보여요. 깃발은 페스티벌마다 따로 만들어요."
      : "앞으로 열리는 페스티벌이에요. 깃발은 페스티벌마다 따로 만들어요.")
  }

  func festivalButton(_ option: BearerFestivalOption) -> some View {
    return BearerZoneButton(
      name: option.title,
      isSelected: store.selectedFestivalID == option.id
    ) {
      send(.festivalTapped(option.id))
    }
  }

  var photoSection: some View {
    FCPhotoPicker(photoState) {
      isPhotoPickerPresented = true
    }
  }

  @ViewBuilder
  func tagSection() -> some View {
    VStack(
      alignment: .leading,
      spacing: Metric.groupSpacing
    ) {
      sectionLabel(
        "성향 태그",
        count: "\(store.form.tags.count) / \(BearerProfileFeature.tagLimit)"
      )
      ScrollView(
        .horizontal,
        showsIndicators: false
      ) {
        HStack(spacing: FestiCoreSpacing.marginM8) {
          ForEach(
            BearerFlagTag.allCases,
            id: \.self
          ) { tag in
            FCChip(tag.title) { send(.tagTapped(tag)) }
              .isSelected(store.form.tags.contains(tag))
          }
        }
      }
      helper("1~3개 고르면 깃발 디렉토리 필터에 걸려요.")
    }
  }

  @ViewBuilder
  func zoneSection() -> some View {
    VStack(
      alignment: .leading,
      spacing: Metric.groupSpacing
    ) {
      sectionLabel(
        "주로 있는 존",
        count: nil
      )
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
          BearerZoneButton(
            name: zone.name,
            isSelected: store.form.homeZoneID == zone.id
          ) {
            send(.zoneTapped(zone.id))
          }
        }
      }
      helper("당일 첫 상태를 올리기 전까지 이 존에 \"예정\"으로 보여요.")
    }
  }

  @ViewBuilder
  func settingSection() -> some View {
    VStack(
      alignment: .leading,
      spacing: Metric.groupSpacing
    ) {
      sectionLabel(
        "오늘 계획 · 함께하는 기수",
        count: nil
      )
      FCListRow(
        "팔로워에게 오늘 계획 보여주기",
        isOn: Binding(
          get: { store.form.planVisible },
          set: { send(.planVisibleChanged($0)) }
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      .overlay {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          .strokeBorder(
            FestiCoreSemanticColor.lineNormal.color,
            lineWidth: 1
          )
      }
      helper("오늘 계획과 공동 기수 초대는 깃발을 만든 뒤 깃발 프로필에서 고를 수 있어요.")
    }
  }

  func doneContent(_ completion: BearerRegisterFeature.Completion) -> some View {
    return GeometryReader { proxy in
      ScrollView {
        VStack(
          alignment: .leading,
          spacing: Metric.doneSectionSpacing
        ) {
          FCDoneHero(
            title: "깃발이 준비됐어요",
            message: doneMessage(completion)
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
            previewCard(completion)
            if completion.photo == .failed {
              helper("사진을 올리지 못했어요. 깃발 프로필에서 다시 골라 주세요.")
            }
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
    .safeAreaInset(
      edge: .bottom,
      spacing: .zero
    ) {
      actionBar {
        FCPrimaryButton(completion.festival.hasPack ? "완료" : "\(completion.festival.name) 팩 받기") {
          send(.primaryDoneTapped)
        }
        FCButton(completion.festival.hasPack ? "공동 기수 초대하기" : "나중에 받을게요") {
          send(.secondaryDoneTapped)
        }
        .style(.ghost)
        .isEnabled(!completion.isInviting)
      }
    }
  }

  func doneMessage(_ completion: BearerRegisterFeature.Completion) -> String {
    guard completion.festival.hasPack else {
      return "현장에서 기수 보드를 쓰려면 \(completion.festival.name) 팩이 필요해요. 지금 받아 두면 통신이 끊겨도 쓸 수 있어요."
    }
    return "공연 당일 기수 보드에서 깃발을 올리면\n팔로워에게 알림이 가요."
  }

  /// Figma S14 E 미리보기: 깃발 목록과 같은 Flag Card(디렉토리), 팔로우 버튼 없음
  func previewCard(_ completion: BearerRegisterFeature.Completion) -> some View {
    let profile = completion.claim.profile
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
    .showsFollow(false)
    .allowsHitTesting(false)
  }

  @ViewBuilder
  var previewThumbnail: some View {
    if let image = image(from: store.photoData) {
      image.resizable().scaledToFill()
    } else {
      FCThumbnail(nil)
    }
  }

  /// Figma S10·S14 Bottom Bar: 글래스 배경, 버튼 사이 4, 위 12·아래 8
  func actionBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
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

  func sectionLabel(
    _ title: String,
    count: String?
  ) -> some View {
    return HStack {
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

  func helper(_ text: String) -> some View {
    return Text(text)
      .festiCoreFont(.baseFootnoteRegular)
      .festiCoreLineBox(.baseFootnoteRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
  }

  var photoState: FCPhotoPicker.State {
    guard let image = image(from: store.photoData) else { return .empty }
    return .filled(image)
  }

  func image(from data: Data?) -> Image? {
    guard let data, let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
  }

  enum Metric {
    /// Figma S14 D Contents 섹션 사이(S10과 같다)
    static let sectionSpacing: CGFloat = 28
    static let groupSpacing: CGFloat = 12
    static let doneSectionSpacing: CGFloat = 40
  }
}

#Preview {
  BearerRegisterView(store: .init(initialState: BearerRegisterFeature.State()) {
    BearerRegisterFeature()
  })
}
