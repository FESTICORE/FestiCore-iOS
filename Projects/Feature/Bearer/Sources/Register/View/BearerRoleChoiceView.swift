//
//  BearerRoleChoiceView.swift
//  Bearer
//
//  Created by FestiCore on 11/12/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

/// Figma S14 C·C2 "페스티벌에서 깃발을 드시나요?"
@ViewAction(for: BearerRoleChoiceFeature.self)
public struct BearerRoleChoiceView: View {
  public let store: StoreOf<BearerRoleChoiceFeature>

  public init(store: StoreOf<BearerRoleChoiceFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back)
        .onBack { send(.backTapped) }
      ScrollView {
        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.marginM24
        ) {
          header()
          VStack(spacing: FestiCoreSpacing.paddingP12) {
            ForEach(
              BearerRoleChoiceFeature.Role.allCases,
              id: \.self
            ) { role in
              roleCard(role)
            }
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      .safeAreaInset(
        edge: .bottom,
        spacing: .zero
      ) {
        FCPrimaryButton(
          "다음",
          isEnabled: store.role != nil
        ) {
          send(.nextTapped)
        }
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP16
        )
        .padding(
          .vertical,
          FestiCoreSpacing.paddingP12
        )
        .background(FestiCoreSemanticColor.backgroundNormal.color)
      }
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
  }
}

private extension BearerRoleChoiceView {
  @ViewBuilder
  func header() -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.marginM8
    ) {
      Text("페스티벌에서\n깃발을 드시나요?")
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Text("기수는 깃발을 들고 사람들을 이끄는 사람이에요. 나중에 마이에서도 바꿀 수 있어요.")
        .festiCoreFont(.baseFootnoteRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  func roleCard(_ role: BearerRoleChoiceFeature.Role) -> some View {
    let isSelected = store.role == role
    return Button {
      send(.roleTapped(role))
    } label: {
      HStack(spacing: FestiCoreSpacing.marginM12) {
        Image(asset: icon(role))
          .resizable()
          .frame(
            width: 20,
            height: 20
          )
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .frame(
            width: 44,
            height: 44
          )
          .background(
            FestiCoreSemanticColor.backgroundAlternative.color,
            in: Circle()
          )
          .accessibilityHidden(true)
        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.paddingP4
        ) {
          Text(title(role))
            .festiCoreFont(.baseCalloutBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          Text(message(role))
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        }
        Spacer(minLength: 0)
        FCCheckCircle(isChecked: isSelected)
      }
      .padding(FestiCoreSpacing.paddingP16)
      .frame(maxWidth: .infinity)
      .background(
        FestiCoreSemanticColor.backgroundNormal.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
      .overlay {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          .strokeBorder(
            isSelected ? FestiCoreSemanticColor.primaryNormal.color : FestiCoreSemanticColor.lineNormal.color,
            lineWidth: isSelected ? 2 : 1
          )
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  func icon(_ role: BearerRoleChoiceFeature.Role) -> ImageAsset {
    switch role {
    case .audience: return .users24
    case .bearer: return .flag20
    }
  }

  func title(_ role: BearerRoleChoiceFeature.Role) -> String {
    switch role {
    case .audience: return "관객이에요"
    case .bearer: return "기수예요"
    }
  }

  func message(_ role: BearerRoleChoiceFeature.Role) -> String {
    switch role {
    case .audience: return "깃발을 팔로우하고 크루와 함께 놀아요"
    case .bearer: return "내 깃발 프로필을 만들고 팔로워를 모아요"
    }
  }
}
