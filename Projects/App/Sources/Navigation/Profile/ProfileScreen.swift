import ComposableArchitecture
import FeatureAssembly

/// 마이 탭의 상세 화면은 ProfileFeature.destination과 설정 홈의 destination을 경로로 투영한다.
@Reducer
enum ProfileScreen {
  case profile(ProfileFeature)
  case packDetail(PackDetailFeature)
  case settings(SettingsHomeFeature)
  case account(AccountSettingsFeature)
  case appearance(AppearanceSettingsFeature)
  case legalDocument(WebFeature)
  case lockScreen(LockScreenSettingsFeature)
  case noticeList(NoticeListFeature)
  case noticeDetail(NoticeDetailFeature)
  case notifications(NotificationSettingsFeature)
}

extension ProfileScreen.State: Equatable {}
