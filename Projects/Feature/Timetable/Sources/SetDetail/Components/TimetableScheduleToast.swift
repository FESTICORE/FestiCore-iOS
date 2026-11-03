//
//  TimetableScheduleToast.swift
//  Timetable
//
//  Created by FestiCore on 11/2/26.
//

import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI

/// 내 일정에 넣은 직후 공연 상세 시트 위에 잠시 보인다. 시트의 `accessory`로 붙인다.
public struct TimetableScheduleToast: View {
  private let isVisible: Bool

  public init(isVisible: Bool) {
    self.isVisible = isVisible
  }

  public var body: some View {
    ZStack {
      if isVisible {
        FCToast(.scheduleAdded())
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.easeOut(duration: Metric.toastDuration), value: isVisible)
  }
}

private extension TimetableScheduleToast {
  enum Metric {
    /// `fcToast`와 같은 등장·퇴장 시간
    static let toastDuration = 0.25
  }
}
