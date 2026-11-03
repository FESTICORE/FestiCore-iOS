//
//  FlagAPITests.swift
//  API
//
//  Created by FestiCore on 11/3/26.
//

import Testing

import API

@Suite("깃발 기수 API 경로")
struct FlagAPITests {
  @Test("깃발·기수 경로를 선언한다")
  func paths() {
    #expect(FestiCoreDomain.flags.path == "api/v1/flags")
    #expect(FestiCoreDomain.bearer.path == "api/v1/bearer")
    #expect(FlagAPI.profile(flagID: "flg_1").path == "api/v1/flags/flg_1")
    #expect(FlagAPI.photo(flagID: "flg_1").path == "api/v1/flags/flg_1/photo")
    #expect(FlagAPI.bearer(flagID: "flg_1").path == "api/v1/flags/flg_1/bearer")
    #expect(FlagAPI.status(flagID: "flg_1").path == "api/v1/flags/flg_1/status")
    #expect(FlagAPI.inviteCoBearer(flagID: "flg_1").path == "api/v1/flags/flg_1/co-bearers/invite")
    #expect(FlagAPI.coBearer(flagID: "flg_1", userID: "usr_2").path == "api/v1/flags/flg_1/co-bearers/usr_2")
    #expect(FlagAPI.claim.path == "api/v1/bearer/claim")
  }
}
