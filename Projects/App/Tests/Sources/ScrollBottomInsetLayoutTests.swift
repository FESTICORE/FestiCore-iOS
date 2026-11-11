import ComposableArchitecture
import FestiCoreDesignKit
import FestivalDomainInterface
import SwiftUI
import UIKit
import XCTest
@testable import FestiCore
@testable import Profile

/// 실제 탭 구성(MainTabView의 TCAFlow NavigationStack + 아래 탭바)에서
/// 스크롤을 끝까지 내렸을 때 마지막 내용과 탭바 사이 간격이 20인지 잰다.
@MainActor
final class ScrollBottomInsetLayoutTests: XCTestCase {
  func testMyTabLastContentStopsTwentyAboveTabBar() async throws {
    var state = MainTabCoordinator.State(selectedTab: .my)
    state.profileState.packLoad = .loaded
    state.profileState.packs = (0..<8).map { index in
      return FestivalReceivedPack(
        id: "fst_\(index)",
        name: "페스티벌 \(index)",
        packVersion: 1
      )
    }
    let store = Store(initialState: state) {
      EmptyReducer<MainTabCoordinator.State, MainTabCoordinator.Action>()
    }
    let gap = try await measureBottomGap(MainTabView(store: store))
    XCTAssertEqual(
      gap,
      FestiCoreSpacing.paddingP20,
      accuracy: 0.5
    )
  }
}

private extension ScrollBottomInsetLayoutTests {
  /// 탭바 자체 높이(홈 인디케이터 영역 제외)
  func tabBarHeight() -> CGFloat {
    let host = UIHostingController(rootView: FCTabBar(selection: .constant(.my)))
    return host.sizeThatFits(in: CGSize(
      width: 393,
      height: 400
    )).height
  }

  /// 세로 스크롤을 맨 끝으로 내린 뒤 (탭바 위쪽 경계) - (스크롤 내용 마지막 줄 아래 경계)를 돌려준다.
  func measureBottomGap<Content: View>(_ content: Content) async throws -> CGFloat {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(
      x: 0,
      y: 0,
      width: 393,
      height: 852
    )
    let controller = UIHostingController(rootView: content)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    controller.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(500))
    let scroll = try XCTUnwrap(verticalScroll(in: controller.view))
    let insets = scroll.adjustedContentInset
    scroll.setContentOffset(
      CGPoint(
        x: 0,
        y: max(
          -insets.top,
          scroll.contentSize.height + insets.bottom - scroll.bounds.height
        )
      ),
      animated: false
    )
    scroll.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(300))
    let scrollFrame = scroll.convert(
      scroll.bounds,
      to: window
    )
    // 맨 끝까지 내렸을 때 내용 마지막 줄의 창 좌표 = 스크롤 아래 경계 - 아래 inset(안전 영역 + contentMargins 20). 간격 = 탭바 위 - 이 값
    let contentBottom = scrollFrame.maxY - insets.bottom
    let tabBarTop = window.bounds.height - window.safeAreaInsets.bottom - tabBarHeight()
    print("[BottomInset] safe=\(window.safeAreaInsets) scrollFrame=\(scrollFrame) adjusted=\(insets) contentInset=\(scroll.contentInset) tabBarTop=\(tabBarTop) contentBottom=\(contentBottom)")
    return tabBarTop - contentBottom
  }

  func verticalScroll(in view: UIView) -> UIScrollView? {
    if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height * 0.5 {
      return scroll
    }
    for child in view.subviews {
      if let found = verticalScroll(in: child) { return found }
    }
    return nil
  }
}
