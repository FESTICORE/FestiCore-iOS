//
//  FCToast+FestiCore.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/31/26.
//

import FestiCoreDesignKit
import SwiftUI

/// FestiCore 화면에서 쓰는 토스트 문구.
public extension FCToast.Item {
  static func booked(_ message: String = "내가 예매한 페스티벌에 담았어요") -> FCToast.Item {
    FCToast.Item(icon: .bookmark16, message: message)
  }

  static func unbooked(_ message: String = "내가 예매한 페스티벌에서 제외했어요") -> FCToast.Item {
    FCToast.Item(icon: .bookmark16, message: message)
  }

  static func noLink(_ message: String = "예매처 정보가 없습니다") -> FCToast.Item {
    FCToast.Item(icon: .circleInfo16, message: message)
  }

  static func scheduleAdded(_ message: String = "내 일정에 추가됐어요") -> FCToast.Item {
    FCToast.Item(icon: .check, message: message)
  }

  static func scheduleRemoved(_ message: String = "내 일정에서 제외했어요") -> FCToast.Item {
    FCToast.Item(icon: .xmark16, message: message)
  }

  static func followed(_ name: String) -> FCToast.Item {
    FCToast.Item(icon: .flag16, message: "\(name)님을 팔로우했습니다")
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP16) {
    FCToast(.booked())
    FCToast(.unbooked())
    FCToast(.noLink())
    FCToast(.scheduleAdded())
    FCToast(.scheduleRemoved())
    FCToast(.followed("호락호락"))
  }
  .padding(FestiCoreSpacing.paddingP16)
}
