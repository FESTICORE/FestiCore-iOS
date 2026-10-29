//
//  MeAPITests.swift
//  API
//
//  Created by FestiCore on 10/29/26.
//

import Testing

import API

@Suite("내 계정 API 경로")
struct MeAPITests {
  @Test("내 계정 경로를 선언한다")
  func path() {
    #expect(MeAPI.allCases == [.me])
    #expect(MeAPI.me.path == "api/v1/me")
  }
}
