import XCTest

extension XCUIApplication {
  /// 앱 시작 직후의 화면을 차례로 넘겨 홈 목록에 닿는다.
  /// 시스템 알림 권한(시작 직후) → 첫 설치 온보딩 → 알림 꺼짐 안내(fcAlert) → S14 A 첫 진입 화면.
  @MainActor
  func passLaunchFlow() {
    let notificationDeny = XCUIApplication(bundleIdentifier: "com.apple.springboard")
      .buttons["허용 안 함"]
    if notificationDeny.waitForExistence(timeout: 8) {
      notificationDeny.tap()
    }
    let onboardingSkip = buttons["onboarding.skip"]
    if onboardingSkip.waitForExistence(timeout: 8) {
      onboardingSkip.tap()
    }
    let notificationLater = buttons["나중에"]
    if notificationLater.waitForExistence(timeout: 8) {
      notificationLater.tap()
    }
    let launchLoginSkip = buttons["launchLogin.skip"]
    if launchLoginSkip.waitForExistence(timeout: 8) {
      launchLoginSkip.tap()
    }
  }
}
