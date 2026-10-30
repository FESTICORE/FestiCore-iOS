//
//  ContentView.swift
//  FestiCoreDesignKitDemo
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 디자인 토큰·컴포넌트 검증 메뉴. 누르면 Figma Design System 섹션별 화면으로 이동한다.
struct ContentView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("Component") {
          NavigationLink("01 Navigation") { NavigationComponentView() }
          NavigationLink("02 Actions") { ActionView() }
          NavigationLink("03 Selection & Input") { SelectionInputView() }
          NavigationLink("04 Labels & Status") { LabelStatusView() }
          NavigationLink("05 List Rows") { ListRowView() }
          NavigationLink("06 Cards") { CardView() }
          NavigationLink("07 Timetable") { TimetableView() }
          NavigationLink("08 Feedback & Overlay") { OverlayView() }
          NavigationLink("09 Media & Brand") { MediaBrandView() }
          NavigationLink("Primary Button") { PrimaryButtonView() }
          NavigationLink("Skeleton") { SkeletonView() }
        }

        Section("Design Token") {
          NavigationLink("Color") { ColorView() }
          NavigationLink("Typography") { TypographyView() }
        }
      }
      .navigationTitle("FestiCore Design Kit")
    }
  }
}

#Preview {
  ContentView()
}
