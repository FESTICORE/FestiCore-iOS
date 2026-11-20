//
//  OnboardingFlowUITests.swift
//  FestiCoreUITests
//
//  Created by FestiCore on 11/21/26.
//

import XCTest

/// 첫 실행 온보딩에서 건너뛰기·페이지 점이 고정되고, 마친 뒤 알림 안내 없이 S14 A 첫 진입 화면이 이어지는지 본다.
@MainActor
final class OnboardingFlowUITests: XCTestCase {
  /// 이 실행에서 알림 권한 팝업을 거부했는지. 거부는 앱 설치에 남아 다음 테스트에도 이어진다.
  private static var hasDeniedNotifications = false

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testPagingKeepsTopActionsAndMovesIndicator() {
    let app = launchOnboarding()
    let skip = app.buttons["onboarding.skip"]
    let indicator = app.descendants(matching: .any)["onboarding.pageIndicator"]
    XCTAssertTrue(indicator.waitForExistence(timeout: 5))
    let skipFrame = skip.frame
    let indicatorFrame = indicator.frame
    XCTAssertEqual(
      indicator.label,
      "1 / 4 페이지"
    )

    // 권한 팝업이 닫힌 직후에도 페이지 영역(그림)에 직접 스와이프한다.
    let page = app.buttons["onboarding.next"].firstMatch
    XCTAssertTrue(page.waitForExistence(timeout: 5))
    // 스플래시에서 온보딩으로 서서히 바뀌는 동안 들어간 스와이프는 무시될 수 있어, 넘어갈 때까지 다시 민다.
    var movedToSecondPage = false
    for _ in 0..<3 where !movedToSecondPage {
      page.swipeLeft()
      movedToSecondPage = waitForLabel(
        indicator,
        "2 / 4 페이지"
      )
    }
    XCTAssertTrue(movedToSecondPage)
    // 그림을 눌러도 다음 페이지로 넘어간다.
    page.tap()
    XCTAssertTrue(waitForLabel(
      indicator,
      "3 / 4 페이지"
    ))

    // 넘긴 뒤에도 건너뛰기와 점은 같은 자리에 있다.
    XCTAssertEqual(
      skip.frame,
      skipFrame
    )
    XCTAssertEqual(
      indicator.frame,
      indicatorFrame
    )
  }

  func testSkipShowsLaunchLoginWithoutNotificationAlert() {
    let launched = launchOnboardingReportingDenial()
    let app = launched.app
    app.buttons["onboarding.skip"].tap()
    let launchLogin = app.buttons["launchLogin.skip"]
    guard launchLogin.waitForExistence(timeout: 10) else {
      // 로그인된 기기에서는 첫 진입 화면 없이 홈으로 간다.
      XCTAssertTrue(app.buttons["라이브"].waitForExistence(timeout: 10))
      return
    }
    // 첫 진입 화면이 덮는 동안 알림 꺼짐 안내가 그 위에 뜨지 않는다.
    XCTAssertFalse(app.buttons["나중에"].waitForExistence(timeout: 2))
    XCTAssertTrue(launchLogin.isHittable)

    // 첫 진입 화면을 닫으면 미뤄 둔 안내가 홈 위에 뜬다.
    launchLogin.tap()
    guard launched.deniedNotifications else { return }
    XCTAssertTrue(app.buttons["나중에"].waitForExistence(timeout: 10))
  }

  private func launchOnboarding() -> XCUIApplication {
    return launchOnboardingReportingDenial().app
  }

  /// 첫 실행 온보딩을 띄운다. 알림 권한 팝업이 뜨면 거부하고, 이 실행에서 거부한 적이 있는지 함께 돌려준다.
  private func launchOnboardingReportingDenial() -> (app: XCUIApplication, deniedNotifications: Bool) {
    let app = XCUIApplication()
    app.launchEnvironment["FESTICORE_ONBOARDING_UI_TEST"] = "1"
    app.launch()
    let deny = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["허용 안 함"]
    if deny.waitForExistence(timeout: 5) {
      deny.tap()
      Self.hasDeniedNotifications = true
    }
    XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 10))
    return (
      app: app,
      deniedNotifications: Self.hasDeniedNotifications
    )
  }

  private func waitForLabel(
    _ element: XCUIElement,
    _ label: String
  ) -> Bool {
    let predicate = NSPredicate(
      format: "label == %@",
      label
    )
    let expectation = XCTNSPredicateExpectation(
      predicate: predicate,
      object: element
    )
    return XCTWaiter.wait(
      for: [expectation],
      timeout: 5
    ) == .completed
  }
}
