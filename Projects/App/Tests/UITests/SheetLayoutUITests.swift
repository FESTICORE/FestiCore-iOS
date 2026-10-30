//
//  SheetLayoutUITests.swift
//  FestiCoreUITests
//
//  Created by FestiCore on 10/31/26.
//

import XCTest

@MainActor
final class SheetLayoutUITests: XCTestCase {
  func testGuestLoginSheetKeepsFestivalListInPlace() {
    let app = XCUIApplication()
    app.launch()

    let notificationDeny = XCUIApplication(bundleIdentifier: "com.apple.springboard")
      .buttons["허용 안 함"]
    if notificationDeny.waitForExistence(timeout: 3) {
      notificationDeny.tap()
    }

    let listTitle = app.staticTexts["페스티벌"].firstMatch
    XCTAssertTrue(listTitle.waitForExistence(timeout: 20))
    let titleY = listTitle.frame.minY
    attachScreenshot(name: "축제 시트 열기 전")

    let bookmark = app.buttons["예매한 페스티벌로 등록"].firstMatch
    XCTAssertTrue(bookmark.waitForExistence(timeout: 10))
    bookmark.tap()

    let sheetTitle = app.staticTexts["축제를 저장하려면 로그인이 필요해요"]
    XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5))
    let message = app.staticTexts["로그인 후 선택한 축제를 저장할 수 있어요."]
    let apple = app.buttons["Apple로 계속"]
    let google = app.buttons["Google로 계속"]
    let later = app.buttons["나중에 할게요"]
    XCTAssertTrue(message.exists)
    XCTAssertTrue(apple.exists)
    XCTAssertTrue(google.exists)
    XCTAssertTrue(later.exists)
    XCTAssertLessThan(abs(listTitle.frame.minY - titleY), 1)
    attachScreenshot(name: "축제 로그인 시트")
    XCTAssertGreaterThan(message.frame.minY, sheetTitle.frame.maxY, "제목과 설명이 겹칩니다")
    XCTAssertGreaterThan(apple.frame.minY, message.frame.maxY, "설명과 Apple 버튼이 겹칩니다")
    XCTAssertGreaterThan(google.frame.minY, apple.frame.maxY, "로그인 버튼이 겹칩니다")
    XCTAssertGreaterThan(later.frame.minY, google.frame.maxY, "Google 버튼과 닫기 버튼이 겹칩니다")
    XCTAssertLessThanOrEqual(later.frame.maxY, app.frame.maxY, "시트 아래쪽이 화면 밖에 있습니다")

    later.tap()
    XCTAssertTrue(sheetTitle.waitForNonExistence(timeout: 5))
    XCTAssertTrue(listTitle.exists)
    XCTAssertLessThan(abs(listTitle.frame.minY - titleY), 1)
    attachScreenshot(name: "축제 로그인 시트 닫은 후")
  }

  private func attachScreenshot(name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
