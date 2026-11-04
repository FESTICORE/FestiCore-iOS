import XCTest

@MainActor
final class PackDownloadDeviceUITests: XCTestCase {
  func testFestivalDetailKeepsTabBar() {
    let app = launchFestivalFixture()

    let card = app.staticTexts.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@",
        "festivalCard_"
      )
    ).firstMatch
    XCTAssertTrue(
      card.waitForExistence(timeout: 30),
      app.debugDescription
    )
    card.tap()

    XCTAssertTrue(
      app.buttons["라이브"].waitForExistence(timeout: 10),
      app.debugDescription
    )
    XCTAssertTrue(
      app.buttons["마이"].exists,
      app.debugDescription
    )
    attachScreenshot(name: "축제 상세 탭바")
  }

  func testPublishedPackCanBeDownloaded() {
    let app = launchFestivalFixture()

    XCTAssertTrue(app.staticTexts["페스티벌"].firstMatch.waitForExistence(timeout: 30))
    let download = app.buttons.matching(
      NSPredicate(
        format: "label == %@ OR label == %@",
        "팩 받기",
        "팩 업데이트"
      )
    ).firstMatch
    XCTAssertTrue(
      download.waitForExistence(timeout: 10),
      app.debugDescription
    )
    attachScreenshot(name: "팩 받기 전")

    download.tap()
    let received = app.staticTexts["팩 받음 · 최신 버전"].firstMatch
    XCTAssertTrue(
      received.waitForExistence(timeout: 10),
      app.debugDescription
    )
    attachScreenshot(name: "팩 받기 완료")
  }

  private func launchFestivalFixture() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["FESTICORE_PACK_UI_TEST"] = "1"
    app.launch()

    let onboardingSkip = app.buttons["onboarding.skip"]
    if onboardingSkip.waitForExistence(timeout: 8) {
      onboardingSkip.tap()
    }
    let notificationDeny = XCUIApplication(bundleIdentifier: "com.apple.springboard")
      .buttons["허용 안 함"]
    if notificationDeny.waitForExistence(timeout: 8) {
      notificationDeny.tap()
    }
    let notificationLater = app.alerts["알림이 꺼져 있어요"].buttons["나중에"]
    if notificationLater.waitForExistence(timeout: 8) {
      notificationLater.tap()
    }
    return app
  }

  private func attachScreenshot(name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
