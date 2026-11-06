import XCTest

@MainActor
final class PackDownloadDeviceUITests: XCTestCase {
  /// 설치된 앱의 실제 세션으로 진입·뒤로가기만 확인하며 서버 일정은 변경하지 않는다.
  func testSchedulePickerNavigationOnDevice() throws {
    #if targetEnvironment(simulator)
    throw XCTSkip("실제 로그인 세션을 사용하는 iPhone 실기기 검증입니다.")
    #else
    let app = XCUIApplication(bundleIdentifier: "io.festiCore.co")
    app.activate()

    let timetable = app.buttons["타임테이블"]
    guard timetable.waitForExistence(timeout: 15), timetable.isHittable else {
      throw XCTSkip("현재 화면에 타임테이블 탭이 없습니다. 선택된 축제와 로그인 상태를 확인해야 합니다.")
    }
    timetable.tap()

    let picker = app.buttons["내 일정 고르기"]
    guard picker.waitForExistence(timeout: 20) else {
      throw XCTSkip("선택된 축제에 공개된 시간표가 없어 일정 선택 진입을 검증할 수 없습니다.")
    }
    let enabled = NSPredicate(format: "enabled == true AND hittable == true")
    let ready = XCTNSPredicateExpectation(
      predicate: enabled,
      object: picker
    )
    guard XCTWaiter.wait(
      for: [ready],
      timeout: 20
    ) == .completed else {
      throw XCTSkip("일정 선택 버튼이 비활성 상태입니다. 로그인 또는 서버 일정 동기화가 준비되지 않았습니다.")
    }

    let title = app.staticTexts["Step 1. 내 일정 고르기"]
    picker.tap()
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["마이"].isHittable)
    XCTAssertFalse(app.buttons["라이브"].isHittable)
    attachScreenshot(name: "실기기 내 일정 선택 push 및 탭바 숨김")

    let edge = app.coordinate(withNormalizedOffset: CGVector(
      dx: 0.02,
      dy: 0.5
    ))
    let destination = app.coordinate(withNormalizedOffset: CGVector(
      dx: 0.85,
      dy: 0.5
    ))
    edge.press(
      forDuration: 0.05,
      thenDragTo: destination
    )
    XCTAssertTrue(title.waitForNonExistence(timeout: 10))
    XCTAssertTrue(picker.waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["마이"].isHittable)
    attachScreenshot(name: "실기기 스와이프 뒤로가기 및 탭바 복원")

    picker.tap()
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    let later = app.buttons["나중에 할게요"]
    XCTAssertTrue(later.waitForExistence(timeout: 5))
    later.tap()
    XCTAssertTrue(title.waitForNonExistence(timeout: 10))
    XCTAssertTrue(picker.waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["마이"].isHittable)
    attachScreenshot(name: "실기기 나중에 선택 후 타임테이블 복원")
    #endif
  }

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
