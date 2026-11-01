//
//  ProfileAccountSheet.swift
//  Profile
//
//  Created by FestiCore on 10/31/26.
//

import AuthDomainInterface
import FestiCoreDesignKit
import SwiftUI

struct ProfileAccountSheet: View {
  let profile: AuthProfile?
  let isLoading: Bool
  let message: String?
  let onRefresh: () -> Void
  let onLogout: () -> Void
  let onWithdraw: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
      Text("계정")
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)

      accountDetails

      if let message, !message.isEmpty, !isLoading {
        Text(message)
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityAddTraits(.updatesFrequently)
      }

      VStack(spacing: FestiCoreSpacing.paddingP8) {
        FCButton("로그아웃", action: onLogout)
          .style(.secondary)
          .isFullWidth(true)
          .isEnabled(!isLoading)

        Button("회원 탈퇴", action: onWithdraw)
          .festiCoreFont(.baseSubheadlineMedium)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .frame(maxWidth: .infinity)
          .frame(height: 40)
          .disabled(isLoading)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, FestiCoreSpacing.paddingP20)
    .padding(.bottom, FestiCoreSpacing.paddingP24)
  }
}

private extension ProfileAccountSheet {
  @ViewBuilder
  var accountDetails: some View {
    if let profile {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(profile.user.nickname ?? profile.user.email ?? "내 계정")
          .festiCoreFont(.baseBodyBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        if let email = profile.user.email {
          Text(email)
            .festiCoreFont(.baseSubheadlineRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(FestiCoreSpacing.paddingP16)
      .background {
        RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
          .fill(FestiCoreSemanticColor.backgroundNormal.color)
      }
    } else if isLoading {
      ProgressView("계정 정보를 확인하는 중입니다")
        .frame(maxWidth: .infinity, minHeight: 72)
    } else {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        if message == nil {
          Text("계정 정보를 확인할 수 없습니다")
            .festiCoreFont(.baseSubheadlineRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        }
        FCButton("계정 정보 다시 확인", action: onRefresh)
          .style(.secondary)
          .size(.medium)
      }
    }
  }
}
