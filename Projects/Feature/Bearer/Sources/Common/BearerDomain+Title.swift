//
//  BearerDomain+Title.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface

/// 여러 기수 화면이 같이 쓰는 태그·활동 이름
extension BearerFlagTag {
  var title: String {
    switch self {
    case .slam: return "슬램"
    case .sing: return "떼창"
    case .train: return "기차놀이"
    case .calm: return "차분"
    case .newbie: return "초보 환영"
    }
  }
}

extension BearerActivity {
  var title: String {
    switch self {
    case .slam: return "슬램"
    case .sing: return "떼창"
    case .train: return "기차놀이"
    case .calm: return "차분"
    }
  }
}
