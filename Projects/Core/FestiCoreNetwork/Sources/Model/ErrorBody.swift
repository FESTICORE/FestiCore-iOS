//
//  ErrorBody.swift
//  FestiCoreNetwork
//
//  Copyright © 2026 FestiCore. All rights reserved.
//

import Foundation

/// 서버 오류 응답에서 선택적으로 읽는 코드와 메시지. 상태 코드만 있어도 오류를 반환한다.
/// API별 오류 응답 형식 차이를 허용하기 위해 필드를 옵셔널로 받는다.
struct ErrorBody: Decodable {
  let code: String?
  let message: String?
}
