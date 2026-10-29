//
//  FestiCoreTabBar.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

import SwiftUI

/// 하단 탭 4개(라이브·타임테이블·깃발·마이). 바탕은 하단 safe area까지 이어진다.
public struct FestiCoreTabBar: View {
  public enum Tab: CaseIterable, Hashable, Sendable {
    case live
    case timetable
    case flag
    case my

    var title: String {
      switch self {
      case .live: return "라이브"
      case .timetable: return "타임테이블"
      case .flag: return "깃발"
      case .my: return "마이"
      }
    }

    func icon(isSelected: Bool) -> ImageAsset {
      switch self {
      case .live: return isSelected ? .navHomeActive : .navHomeInactive
      case .timetable: return isSelected ? .navTimetableActive : .navTimetableInactive
      case .flag: return isSelected ? .navFlagActive : .navFlagInactive
      case .my: return isSelected ? .navMyActive : .navMyInactive
      }
    }
  }

  @Binding private var selection: Tab

  public init(selection: Binding<Tab>) {
    self._selection = selection
  }

  public var body: some View {
    HStack(spacing: .zero) {
      ForEach(Tab.allCases, id: \.self) { tab in
        tabButton(tab)
      }
    }
    .padding(.top, FestiCoreSpacing.paddingP8)
    .padding(.bottom, FestiCoreSpacing.paddingP8)
    .background {
      Rectangle()
        .fill(.ultraThinMaterial)
        .overlay(FestiCoreSemanticColor.materialGlass.color)
        .ignoresSafeArea(edges: .bottom)
    }
    .overlay(alignment: .top) {
      FestiCoreDivider()
    }
  }

  private func tabButton(_ tab: Tab) -> some View {
    let isSelected = selection == tab

    return Button {
      selection = tab
    } label: {
      VStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(asset: tab.icon(isSelected: isSelected))
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
        Text(tab.title)
          .festiCoreTextStyle(isSelected ? .baseCaption2Bold : .baseCaption2Medium)
          .lineLimit(1)
      }
      .foregroundStyle(
        isSelected
          ? FestiCoreSemanticColor.labelNormal.color
          : FestiCoreSemanticColor.labelAssistive.color
      )
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(tab.title)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private extension FestiCoreTabBar {
  enum Metric {
    static let iconSize: CGFloat = 24
  }
}
