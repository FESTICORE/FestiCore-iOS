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

/// 시트 안 콘텐츠가 딤 탭·아래로 끌기로 닫히지 않게 막을 때 올리는 값
public struct FCSheetDismissDisabledKey: PreferenceKey {
  public static let defaultValue = false

  public static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

public extension View {
  /// 참이면 이 뷰를 담은 FC 시트를 딤 탭이나 아래로 끌어서 닫을 수 없다. 저장 중처럼 잠깐 막을 때 쓴다.
  func fcSheetDismissDisabled(_ isDisabled: Bool) -> some View {
    preference(key: FCSheetDismissDisabledKey.self, value: isDisabled)
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
  @State private var isDismissDisabled = false

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
    content
      .onChange(of: item) { oldValue, newValue in
        // 닫히거나 다른 아이템으로 바뀌면 이전 콘텐츠가 남긴 닫기 막기를 풀어 다음 시트가 닫히게 한다.
        isDismissDisabled = false
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
        GeometryReader { geometry in
          ZStack(alignment: .bottom) {
            if item != nil {
              FestiCoreSemanticColor.materialDimmer.color
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { if !isDismissDisabled { dismiss() } }
                .accessibilityLabel("닫기")
                .accessibilityAddTraits(.isButton)
                // 닫기가 막혀 있으면 VoiceOver에도 닫기 버튼을 알리지 않는다.
                .accessibilityHidden(isDismissDisabled)
            }
            sheet(geometry: geometry)
          }
          .animation(.easeOut(duration: Metric.longDuration), value: item != nil)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .allowsHitTesting(item != nil)
      }
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
          .onPreferenceChange(FCSheetDismissDisabledKey.self) { isDismissDisabled = $0 }
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
        guard !isDismissDisabled else { return }
        isDragging = true
        dragOffset = max(0, value.translation.height)
      }
      .onEnded { value in
        isDragging = false
        if !isDismissDisabled, value.translation.height > Metric.dismissThreshold {
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
  // Attendance CustomModalModifier와 같은 이동 거리와 닫기 타이밍을 사용한다.
  static let slideDistance: CGFloat = 400
  static let dismissThreshold: CGFloat = 100
  static let shortDuration: Double = 0.2
  static let mediumDuration: Double = 0.3
  static let longDuration: Double = 0.4
}
