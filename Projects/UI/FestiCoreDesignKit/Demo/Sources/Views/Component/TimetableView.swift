//
//  TimetableView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

struct TimetableView: View {
  var body: some View {
    DemoPage("07 Timetable 검증") {
      DemoSection("Stage Header") {
        FCStageHeader(name: "메인 스테이지")
        FCStageHeader(name: "서브 스테이지")
          .dotColor(.accentPointOrange)
      }
      DemoSection("Set Block (default · mine · changed · overlap)") {
        HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP8) {
          FCSetBlock(artist: "아티스트", time: "18:00 - 19:00")
            .frame(height: FCSetBlock.height(minutes: 60))
          FCSetBlock(artist: "아티스트", time: "18:00 - 19:00")
            .state(.mine)
            .frame(height: FCSetBlock.height(minutes: 60))
        }
        HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP8) {
          FCSetBlock(artist: "아티스트", time: "18:30 - 19:30")
            .state(.changed(oldTime: "18:00", change: "30분 지연"))
            .frame(height: FCSetBlock.height(minutes: 60))
          FCSetBlock(artist: "아티스트", time: "18:00 - 18:20")
            .state(.overlap())
            .frame(height: FCSetBlock.height(minutes: 20))
        }
      }
      DemoSection("Now Line · Overlap Highlight") {
        FCNowLine(time: "18:30")
        FCOverlapHighlight()
          .frame(height: 40)
      }
    }
  }
}

#Preview {
  NavigationStack {
    TimetableView()
  }
}
