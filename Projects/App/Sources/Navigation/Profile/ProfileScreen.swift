import ComposableArchitecture
import FeatureAssembly

/// 마이 탭의 상세 화면은 ProfileFeature.destination을 경로로 투영한다.
@Reducer
enum ProfileScreen {
  case profile(ProfileFeature)
  case packDetail(PackDetailFeature)
  case account(AccountSettingsFeature)
  case legalDocument(WebFeature)
  case lockScreen(LockScreenSettingsFeature)
  case noticeList(NoticeListFeature)
  case noticeDetail(NoticeDetailFeature)
  case notifications(NotificationSettingsFeature)
}

extension ProfileScreen.State: Equatable {}
