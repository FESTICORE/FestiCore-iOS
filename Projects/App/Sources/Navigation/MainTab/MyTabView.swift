import AuthDomainInterface
import FestiCoreDesignKit
import SwiftUI

struct MyTabView: View {
  let profile: AuthProfile?
  let hasSession: Bool
  let isLoading: Bool
  let message: String?
  let onLogin: () -> Void
  let onRefresh: () -> Void
  let onLogout: () -> Void
  let onWithdraw: () -> Void

  @State private var isWithdrawalConfirmationPresented = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
        Text("마이")
          .festiCoreFont(.baseTitle1Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)

        if let profile {
          account(profile)
        } else if isLoading {
          ProgressView("계정 정보를 확인하는 중입니다")
            .frame(maxWidth: .infinity, minHeight: 180)
        } else {
          FCEmptyCard(
            title: hasSession || message != nil ? "계정 정보를 확인할 수 없습니다" : "로그인이 필요합니다",
            message: hasSession || message != nil
              ? "네트워크 연결을 확인하고 다시 시도해 주세요."
              : "로그인하면 계정 정보를 확인할 수 있습니다."
          )
          if !hasSession {
            Button("로그인하기", action: onLogin)
              .buttonStyle(.borderedProminent)
          }
          Button("계정 정보 다시 확인", action: onRefresh)
        }

        if profile != nil || hasSession {
          Button("로그아웃", action: onLogout)
            .disabled(isLoading)
          Button("회원 탈퇴", role: .destructive) {
            isWithdrawalConfirmationPresented = true
          }
          .disabled(isLoading)
        }

        if let message {
          Text(message)
            .festiCoreFont(.baseSubheadlineRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        }
      }
      .buttonStyle(.plain)
      .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      .padding(.horizontal, FestiCoreSpacing.paddingP20)
      .padding(.top, FestiCoreSpacing.paddingP24)
      .padding(.bottom, FestiCoreSpacing.paddingP24)
    }
    .scrollIndicators(.hidden)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .alert("회원 탈퇴", isPresented: $isWithdrawalConfirmationPresented) {
      Button("탈퇴", role: .destructive, action: onWithdraw)
      Button("취소", role: .cancel) {}
    } message: {
      Text("계정과 로그인 정보가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
    }
  }

  private func account(_ profile: AuthProfile) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      Text(profile.user.nickname ?? profile.user.email ?? "내 계정")
        .festiCoreFont(.baseTitle3Bold)
      if let email = profile.user.email {
        Text(email)
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
      Text(profile.user.provider == "apple" ? "Apple 계정" : "Google 계정")
        .festiCoreFont(.baseCaption1Regular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(FestiCoreSpacing.paddingP16)
    .background(FestiCoreSemanticColor.backgroundElevated.color,
                in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
  }
}
