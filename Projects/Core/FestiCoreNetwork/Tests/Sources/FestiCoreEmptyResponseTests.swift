//
//  FestiCoreEmptyResponseTests.swift
//  FestiCoreNetwork
//
//  바디 없는 응답이 디코딩 에러로 떨어지지 않는지 검증한다.
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation
import Testing

import FestiCoreNetworkInterface

@Suite("FestiCoreEmptyResponse — 빈 응답 디코딩")
struct FestiCoreEmptyResponseTests {
  private func decode(_ json: String) throws -> FestiCoreEmptyResponse {
    try JSONDecoder().decode(FestiCoreEmptyResponse.self, from: Data(json.utf8))
  }

  @Test("빈 객체를 받는다", arguments: ["{}", "[]", "\"\"", "null", "0"])
  func decodesAnyShape(_ json: String) throws {
    _ = try decode(json)
  }

  @Test("바디가 아예 없으면 emptyValue 로 성공 처리된다")
  func providesEmptyValue() {
    _ = FestiCoreEmptyResponse.emptyValue()
  }
}
