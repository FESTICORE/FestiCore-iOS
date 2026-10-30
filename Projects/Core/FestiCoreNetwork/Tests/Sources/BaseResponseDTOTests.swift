//
//  BaseResponseDTOTests.swift
//  FestiCoreNetwork
//
//  Created by FestiCore on 10/31/26.
//

import FestiCoreNetworkInterface
import Foundation
import Testing

@Suite("공통 응답 봉투")
struct BaseResponseDTOTests {
  private struct Payload: Decodable, Equatable, Sendable {
    let id: String
  }

  @Test("코드와 메시지, 데이터를 디코딩한다")
  func decodesSuccess() throws {
    let json = Data(#"{"code":"SUCCESS","message":"성공","data":{"id":"festival-1"}}"#.utf8)
    let response = try JSONDecoder().decode(BaseResponseDTO<Payload>.self, from: json)

    #expect(response.code == "SUCCESS")
    #expect(response.message == "성공")
    #expect(response.data.id == "festival-1")
  }

  @Test("nullable 데이터는 Optional 별칭으로 디코딩한다")
  func decodesNullData() throws {
    let json = Data(#"{"code":"SUCCESS","message":"데이터 없음","data":null}"#.utf8)
    let response = try JSONDecoder().decode(BaseResponseDTO<Payload?>.self, from: json)

    #expect(response.code == "SUCCESS")
    #expect(response.message == "데이터 없음")
    #expect(response.data == nil)
  }

  @Test("필수 메시지가 없으면 디코딩에 실패한다")
  func requiresMessage() {
    let json = Data(#"{"code":"SUCCESS","data":{"id":"festival-1"}}"#.utf8)

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(BaseResponseDTO<Payload>.self, from: json)
    }
  }

  @Test("동일한 payload의 응답을 비교한다")
  func supportsEquatable() {
    let response = BaseResponseDTO(code: "SUCCESS", message: "성공", data: Payload(id: "festival-1"))
    #expect(response == BaseResponseDTO(code: "SUCCESS", message: "성공", data: Payload(id: "festival-1")))
    #expect(response != BaseResponseDTO(code: "SUCCESS", message: "성공", data: Payload(id: "festival-2")))
  }
}
