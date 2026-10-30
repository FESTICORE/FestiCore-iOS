//
//  FCSheetModifier.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 시트 안에서 닫기를 요청할 때 쓰는 동작.
public struct FCSheetDismissKey: EnvironmentKey {
  public static let defaultValue: () -> Void = {}
}

public extension EnvironmentValues {
  var fcSheetDismiss: () -> Void {
    get { self[FCSheetDismissKey.self] }
    set { self[FCSheetDismissKey.self] = newValue }
  }
}

/// 바텀시트 높이.
public enum FCSheetHeight: Sendable {
  case fraction(CGFloat)
  case fixed(CGFloat)
  case auto
}

/// 아래에서 올라오는 바텀시트. 위쪽 손잡이, 반경 24 모서리, 딤 배경을 그리고 아래로 끌거나 딤을 누르면 닫힌다.
/// `item`이 `nil`이 되면 닫히므로 TCA 상태(예: `destination`)와 바로 연결할 수 있다.
public struct FCSheetModifier<Item: Identifiable & Equatable, SheetContent: View>: ViewModifier {
  @Binding var item: Item?
  let height: FCSheetHeight
  let showsGrabber: Bool
  let sheetContent: (Item) -> SheetContent

  @State private var dragOffset: CGFloat = 0
  @State private var dismissOffset: CGFloat = 0
  @State private var isDragging = false

  public init(
    item: Binding<Item?>,
    height: FCSheetHeight = .auto,
    showsGrabber: Bool = true,
    @ViewBuilder content: @escaping (Item) -> SheetContent
  ) {
    _item = item
    self.height = height
    self.showsGrabber = showsGrabber
    sheetContent = content
  }

  public func body(content: Content) -> some View {
    GeometryReader { geometry in
      content
        .overlay {
          if item != nil {
            ZStack(alignment: .bottom) {
              FestiCoreSemanticColor.materialDimmer.color
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { dismiss() }
                .accessibilityLabel("닫기")
                .accessibilityAddTraits(.isButton)
              sheet(geometry: geometry)
            }
          }
        }
    }
    .ignoresSafeArea(.keyboard, edges: .bottom)
  }

  @ViewBuilder
  private func sheet(geometry: GeometryProxy) -> some View {
    if let currentItem = item {
      VStack(spacing: FestiCoreSpacing.paddingP16) {
        if showsGrabber {
          Capsule()
            .fill(FestiCoreSemanticColor.lineNormal.color)
            .frame(width: Metric.grabberWidth, height: Metric.grabberHeight)
            .padding(.top, FestiCoreSpacing.paddingP8)
            .accessibilityHidden(true)
        }
        sheetContent(currentItem)
          .frame(maxWidth: .infinity)
          .frame(height: heightValue(for: geometry))
          .environment(\.fcSheetDismiss, dismiss)
      }
      .padding(.bottom, geometry.safeAreaInsets.bottom)
      .background(FestiCoreSemanticColor.backgroundElevated.color)
      .clipShape(UnevenRoundedRectangle(topLeadingRadius: FestiCoreRadius.r24, topTrailingRadius: FestiCoreRadius.r24))
      .offset(y: dragOffset + dismissOffset)
      .animation(isDragging ? nil : .easeOut(duration: Metric.shortDuration), value: dragOffset)
      .gesture(dragGesture)
      .ignoresSafeArea(edges: .bottom)
      .transition(.move(edge: .bottom))
      .onAppear {
        dismissOffset = Metric.slideDistance
        withAnimation(.easeOut(duration: Metric.longDuration)) {
          dismissOffset = 0
        }
      }
      .accessibilityAddTraits(.isModal)
    }
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        isDragging = true
        dragOffset = max(0, value.translation.height)
      }
      .onEnded { value in
        isDragging = false
        if value.translation.height > Metric.dismissThreshold {
          dismiss()
        } else {
          withAnimation(.easeOut(duration: Metric.shortDuration)) {
            dragOffset = 0
          }
        }
      }
  }

  private func dismiss() {
    withAnimation(.easeOut(duration: Metric.mediumDuration)) {
      dismissOffset = Metric.slideDistance
    }
    dragOffset = 0
    DispatchQueue.main.asyncAfter(deadline: .now() + Metric.mediumDuration) {
      item = nil
      dismissOffset = 0
    }
  }

  private func heightValue(for geometry: GeometryProxy) -> CGFloat? {
    let available = geometry.size.height - geometry.safeAreaInsets.bottom
    switch height {
    case let .fraction(fraction): return min(available * fraction, available)
    case let .fixed(points): return min(points, available)
    case .auto: return nil
    }
  }
}

public extension View {
  /// `item`이 있으면 바텀시트를 띄운다.
  func presentFCSheet<Item: Identifiable & Equatable, SheetContent: View>(
    item: Binding<Item?>,
    height: FCSheetHeight = .auto,
    showsGrabber: Bool = true,
    @ViewBuilder content: @escaping (Item) -> SheetContent
  ) -> some View {
    modifier(
      FCSheetModifier(
        item: item,
        height: height,
        showsGrabber: showsGrabber,
        content: content
      )
    )
  }
}

private enum Metric {
  static let grabberWidth: CGFloat = 36
  static let grabberHeight: CGFloat = 5
  static let slideDistance: CGFloat = 600
  static let dismissThreshold: CGFloat = 100
  static let shortDuration: Double = 0.2
  static let mediumDuration: Double = 0.3
  static let longDuration: Double = 0.4
}
