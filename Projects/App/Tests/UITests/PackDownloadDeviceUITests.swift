import XCTest

@MainActor
final class PackDownloadDeviceUITests: XCTestCase {
  func testFestivalDetailKeepsTabBar() {
    let app = XCUIApplication()
    app.launch()

    let onboardingSkip = app.buttons["onboarding.skip"]
    if onboardingSkip.waitForExistence(timeout: 8) {
      onboardingSkip.tap()
    }

    let card = app.descendants(matching: .any).matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@",
        "festival.card."
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
    let app = XCUIApplication()
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

    XCTAssertTrue(app.staticTexts["페스티벌"].firstMatch.waitForExistence(timeout: 30))
    let download = app.buttons.matching(
      NSPredicate(
        format: "label == %@ OR label == %@",
        "팩 받기",
        "팩 업데이트"
      )
    ).firstMatch
    for _ in 0..<20 {
      if download.exists { break }
      app.swipeUp()
    }
    XCTAssertTrue(
      download.waitForExistence(timeout: 10),
      app.debugDescription
    )
    attachScreenshot(name: "팩 받기 전")

    download.tap()
    let received = app.staticTexts["팩 받음 · 최신 버전"].firstMatch
    XCTAssertTrue(
      received.waitForExistence(timeout: 90),
      app.debugDescription
    )
    attachScreenshot(name: "팩 받기 완료")
  }

  private func attachScreenshot(name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
