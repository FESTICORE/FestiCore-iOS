//
//  GoogleSignInLinkTests.swift
//  FestiCore
//
//  Created by FestiCore on 11/3/26.
//

import Foundation
import Testing

/// 앱이 실제로 불러온 GoogleSignIn이 로그인 화면 표시에 쓰는 AppAuth iOS 카테고리를 포함하는지 확인한다.
/// 빠지면 Google 로그인 버튼을 누르는 순간 `unrecognized selector`로 앱이 종료된다.
struct GoogleSignInLinkTests {
  @Test func appAuthPresentationCategoryIsLinked() throws {
    let service = try #require(NSClassFromString("OIDAuthorizationService") as? NSObject.Type)
    let selector = NSSelectorFromString("presentAuthorizationRequest:presentingViewController:callback:")
    #expect(service.responds(to: selector))
  }
}
