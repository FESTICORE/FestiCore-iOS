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
  /// 마이에서 연 기수 설정(S14 D·S13 F~I·S10·S09). 화면 상태는 `ProfileCoordinator.State.bearer`가 가진다.
  case bearer(BearerEntryStep)
}

extension ProfileScreen.State: Equatable {}
