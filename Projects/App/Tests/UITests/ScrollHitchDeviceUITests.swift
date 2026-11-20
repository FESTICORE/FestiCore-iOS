//
//  ScrollHitchDeviceUITests.swift
//  FestiCoreUITests
//
//  Created by FestiCore on 11/20/26.
//

import XCTest

/// 실기기에서 라이브 보드와 타임테이블 세로 스크롤의 끊김(Hitch)을 잰다.
/// 설치된 앱의 실제 세션과 선택 축제를 그대로 쓰며 서버 상태는 바꾸지 않는다.
@MainActor
final class ScrollHitchDeviceUITests: XCTestCase {
  func testLiveBoardScrollHitches() throws {
    #if targetEnvironment(simulator)
    throw XCTSkip("끊김 지표는 iPhone 실기기에서만 기록된다.")
    #else
    let app = XCUIApplication(bundleIdentifier: "io.festiCore.co")
    app.activate()
    // 새 빌드를 설치하면 첫 진입 흐름(알림 · 온보딩 · 로그인)이 다시 뜰 수 있어 건너뛴다.
    app.passLaunchFlow()
    let live = app.buttons["라이브"]
    guard live.waitForExistence(timeout: 15) else {
      attachScreenshot(name: "라이브 탭을 찾지 못한 화면")
      throw XCTSkip("라이브 탭이 없습니다. 첫 진입 흐름을 마친 상태인지 확인해야 합니다.")
    }
    live.tap()
    let card = app.staticTexts["festivalCard_fst_00e0f4f1d8065a93"].firstMatch
    if card.waitForExistence(timeout: 5) {
      card.tap()
    }
    let scroll = app.scrollViews.firstMatch
    XCTAssertTrue(scroll.waitForExistence(timeout: 20))
    // 온라인 상세 · 라이브 보드 · 이미지를 받을 시간을 둔다.
    sleep(6)
    attachScreenshot(name: "라이브 보드 측정 전")
    measureScroll(scroll)
    #endif
  }

  func testTimetableScrollHitches() throws {
    #if targetEnvironment(simulator)
    throw XCTSkip("끊김 지표는 iPhone 실기기에서만 기록된다.")
    #else
    let app = XCUIApplication(bundleIdentifier: "io.festiCore.co")
    app.activate()
    app.passLaunchFlow()
    let timetable = app.buttons["타임테이블"]
    guard timetable.waitForExistence(timeout: 15) else {
      attachScreenshot(name: "타임테이블 탭을 찾지 못한 화면")
      throw XCTSkip("타임테이블 탭이 없습니다. 첫 진입 흐름을 마친 상태인지 확인해야 합니다.")
    }
    timetable.tap()
    let scroll = app.scrollViews.firstMatch
    XCTAssertTrue(scroll.waitForExistence(timeout: 20))
    sleep(4)
    attachScreenshot(name: "타임테이블 측정 전")
    measureScroll(scroll)
    #endif
  }

  /// 빠르게 위로 밀어 감속까지 재고, 측정 밖에서 원래 위치로 되돌린다.
  private func measureScroll(_ scroll: XCUIElement) {
    let options = XCTMeasureOptions()
    options.invocationOptions = [.manuallyStop]
    options.iterationCount = 5
    measure(
      metrics: [
        XCTOSSignpostMetric.scrollDecelerationMetric,
        XCTOSSignpostMetric.scrollDraggingMetric,
      ],
      options: options
    ) {
      scroll.swipeUp(velocity: .fast)
      stopMeasuring()
      scroll.swipeDown(velocity: .fast)
      scroll.swipeDown(velocity: .fast)
    }
  }

  private func attachScreenshot(name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
