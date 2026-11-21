//
//  WidgetLaunchSessionDeviceUITests.swift
//  FestiCoreUITests
//
//  Created by FestiCore on 11/21/26.
//

import XCTest

/// 실기기에서 위젯 URL로 앱을 처음부터 열어도 로그인 세션이 유지되는지 본다.
/// 설치된 앱의 실제 세션을 그대로 쓰며 서버 상태는 바꾸지 않는다.
@MainActor
final class WidgetLaunchSessionDeviceUITests: XCTestCase {
  func testWidgetURLColdLaunchKeepsSession() throws {
    #if targetEnvironment(simulator)
    throw XCTSkip("설치된 앱의 실제 세션은 iPhone 실기기에서만 확인한다.")
    #else
    let app = XCUIApplication(bundleIdentifier: "io.festiCore.co")
    app.activate()
    sleep(8)
    attachScreenshot(name: "1 일반 실행")
    let wasLoggedOut = isLaunchLoginShown(in: app)
    app.terminate()
    app.open(URL(string: "festicore://festival")!)
    sleep(8)
    attachScreenshot(name: "2 위젯 URL 냉시작")
    let isLoggedOut = isLaunchLoginShown(in: app)
    if wasLoggedOut {
      throw XCTSkip("처음부터 로그아웃 상태라 세션 유지 여부를 판단할 수 없다.")
    }
    XCTAssertFalse(
      isLoggedOut,
      "위젯 URL로 냉시작하자 로그인 첫 진입 화면이 떴다."
    )
    #endif
  }

  private func isLaunchLoginShown(in app: XCUIApplication) -> Bool {
    return app.descendants(matching: .any)["launchLogin.skip"].exists
  }

  private func attachScreenshot(name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
