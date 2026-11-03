//
//  String+Josa.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import Foundation

extension String {
  /// 마지막 글자의 받침에 맞는 조사를 붙인다. 예: "존" + ("으로", "로") → "존으로"
  func withJosa(_ afterBatchim: String, _ afterVowel: String, rieulTakesVowelForm: Bool = false) -> String {
    guard let scalar = unicodeScalars.last, (0xAC00 ... 0xD7A3).contains(scalar.value) else {
      return self + afterVowel
    }
    let jongseong = (scalar.value - 0xAC00) % 28
    if jongseong == 0 || (rieulTakesVowelForm && jongseong == 8) {
      return self + afterVowel
    }
    return self + afterBatchim
  }

  /// "…으로/로". 받침 ㄹ 뒤에는 "로"를 쓴다.
  var withEuro: String { withJosa("으로", "로", rieulTakesVowelForm: true) }
  /// "…이/가"
  var withIga: String { withJosa("이", "가") }
}
