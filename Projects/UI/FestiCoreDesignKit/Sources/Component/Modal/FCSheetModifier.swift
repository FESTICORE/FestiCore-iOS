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

private struct FCSheetDismissalDelayKey: EnvironmentKey {
  static let defaultValue = Metric.mediumDuration
}

extension EnvironmentValues {
  var fcSheetDismissalDelay: Double {
    get { self[FCSheetDismissalDelayKey.self] }
    set { self[FCSheetDismissalDelayKey.self] = newValue }
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
/// `accessory`는 시트 위쪽 가장자리 16pt 위에 붙어 시트와 함께 움직이고, 닫기가 시작되면 바로 감춰진다(토스트 등).
public struct FCSheetModifier<Item: Identifiable & Equatable, SheetContent: View, Accessory: View>: ViewModifier {
  @Binding var item: Item?
  let height: FCSheetHeight
  let showsGrabber: Bool
  let sheetContent: (Item) -> SheetContent
  let accessory: (Item) -> Accessory

  @Environment(\.fcSheetDismissalDelay) private var dismissalDelay
  @State private var dragOffset: CGFloat = 0
  @State private var dismissOffset: CGFloat = 0
  @State private var isDragging = false
  @State private var pendingDismissal: DispatchWorkItem?

  public init(
    item: Binding<Item?>,
    height: FCSheetHeight = .auto,
    showsGrabber: Bool = true,
    @ViewBuilder content: @escaping (Item) -> SheetContent,
    @ViewBuilder accessory: @escaping (Item) -> Accessory
  ) {
    _item = item
    self.height = height
    self.showsGrabber = showsGrabber
    sheetContent = content
    self.accessory = accessory
  }

  public func body(content: Content) -> some View {
    GeometryReader { geometry in
      content
        .onChange(of: item) { oldValue, newValue in
          let wasDismissing = pendingDismissal != nil
          cancelPendingDismissal()
          if newValue != nil, oldValue == nil || wasDismissing {
            dragOffset = 0
            dismissOffset = 0
            isDragging = false
          }
        }
        .onDisappear {
          if item == nil { cancelPendingDismissal() }
        }
        .overlay {
          ZStack(alignment: .bottom) {
            if item != nil {
              FestiCoreSemanticColor.materialDimmer.color
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { dismiss() }
                .accessibilityLabel("닫기")
                .accessibilityAddTraits(.isButton)
            }
            sheet(geometry: geometry)
          }
          .animation(.easeOut(duration: Metric.longDuration), value: item != nil)
        }
    }
    .ignoresSafeArea(.keyboard, edges: .bottom)
  }

}

extension FCSheetModifier {
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
      .overlay(alignment: .top) {
        accessory(currentItem)
          .alignmentGuide(.top) { $0[.bottom] + FestiCoreSpacing.paddingP16 }
          .opacity(pendingDismissal == nil ? 1 : 0)
      }
      // 이동 중 배경과 내부 요소가 같은 기하 변환을 적용받도록 한다.
      .geometryGroup()
      .offset(y: dragOffset + dismissOffset)
      .animation(isDragging ? nil : .easeOut(duration: Metric.shortDuration), value: dragOffset)
      .gesture(dragGesture)
      .ignoresSafeArea(edges: .bottom)
      .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .identity))
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
    guard let dismissedItem = item else { return }
    cancelPendingDismissal()
    withAnimation(.easeOut(duration: Metric.mediumDuration)) {
      dismissOffset = Metric.slideDistance
    }
    dragOffset = 0
    let work = DispatchWorkItem {
      guard item == dismissedItem else { return }
      Self.completeDismissal(of: dismissedItem, item: $item)
      dismissOffset = 0
      pendingDismissal = nil
    }
    pendingDismissal = work
    DispatchQueue.main.asyncAfter(deadline: .now() + dismissalDelay, execute: work)
  }

  private func cancelPendingDismissal() {
    pendingDismissal?.cancel()
    pendingDismissal = nil
  }

  static func completeDismissal(of dismissedItem: Item, item: Binding<Item?>) {
    guard item.wrappedValue == dismissedItem else { return }
    item.wrappedValue = nil
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

public extension FCSheetModifier where Accessory == EmptyView {
  init(
    item: Binding<Item?>,
    height: FCSheetHeight = .auto,
    showsGrabber: Bool = true,
    @ViewBuilder content: @escaping (Item) -> SheetContent
  ) {
    self.init(
      item: item,
      height: height,
      showsGrabber: showsGrabber,
      content: content,
      accessory: { _ in EmptyView() }
    )
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

  /// `item`이 있으면 바텀시트를 띄우고 시트 위에 `accessory`(토스트 등)를 붙인다.
  func presentFCSheet<Item: Identifiable & Equatable, SheetContent: View, Accessory: View>(
    item: Binding<Item?>,
    height: FCSheetHeight = .auto,
    showsGrabber: Bool = true,
    @ViewBuilder content: @escaping (Item) -> SheetContent,
    @ViewBuilder accessory: @escaping (Item) -> Accessory
  ) -> some View {
    modifier(
      FCSheetModifier(
        item: item,
        height: height,
        showsGrabber: showsGrabber,
        content: content,
        accessory: accessory
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
