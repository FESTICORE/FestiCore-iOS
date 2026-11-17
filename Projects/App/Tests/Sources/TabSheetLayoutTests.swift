import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI
import UIKit
import XCTest
@testable import FestiCore
@testable import Festival

/// 실제 탭 구성(MainTabView의 TCAFlow NavigationStack + 아래 탭바)에서 push된 화면이 띄운 시트가
/// 숨긴 탭바 자리까지 화면 아래 끝을 덮는지 본다. 실기기에서 시트 아래가 잘려 탭바 높이의 띠가 남았다.
@MainActor
final class TabSheetLayoutTests: XCTestCase {
  func testPushedScreenSheetCoversTabBarArea() async throws {
    var board = FestivalFeature.State()
    board.festivalSwitcher = .init(
      festivals: [.init(
        id: "festival-a",
        name: "원더리벳 2026",
        subtitle: "오늘 · DAY 1 진행 중",
        thumbnailURL: nil
      )],
      selectedFestivalID: "festival-a"
    )
    var state = MainTabCoordinator.State(selectedTab: .live)
    state.festivalState.routes.push(.liveBoard(board))
    let store = Store(initialState: state) {
      EmptyReducer<MainTabCoordinator.State, MainTabCoordinator.Action>()
    }

    let bottom = try await bottomPixel(of: MainTabView(store: store))

    let sheet = UIColor(FestiCoreSemanticColor.backgroundElevated.color)
      .resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    XCTAssertTrue(
      bottom.isClose(to: sheet),
      "화면 아래 끝 색 \(bottom)이 시트 배경 \(sheet)과 달라 시트가 탭바 자리에서 잘렸습니다."
    )
  }
}

private extension TabSheetLayoutTests {
  /// 다크 모드로 그린 뒤 화면 아래 끝 가운데(홈 인디케이터 위) 한 점의 색을 돌려준다.
  func bottomPixel<Content: View>(of content: Content) async throws -> UIColor {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(
      x: 0,
      y: 0,
      width: 393,
      height: 852
    )
    window.overrideUserInterfaceStyle = .dark
    let controller = UIHostingController(rootView: content)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    controller.view.layoutIfNeeded()
    // 시트 표시를 알리는 preference가 탭바 자리를 비우고 시트 등장 애니메이션이 끝날 때까지 기다린다.
    try await Task.sleep(for: .milliseconds(1200))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    // 넓은 색 영역(16비트)이 아닌 8비트 sRGB로 그려 픽셀을 바로 읽는다.
    format.preferredRange = .standard
    let image = UIGraphicsImageRenderer(
      bounds: window.bounds,
      format: format
    ).image { _ in
      _ = window.drawHierarchy(
        in: window.bounds,
        afterScreenUpdates: true
      )
    }
    let attachment = XCTAttachment(image: image)
    attachment.name = "tab-sheet-bottom"
    attachment.lifetime = .keepAlways
    add(attachment)
    return try XCTUnwrap(image.color(at: CGPoint(
      x: window.bounds.midX,
      y: window.bounds.maxY - 12
    )))
  }
}

private extension UIImage {
  func color(at point: CGPoint) -> UIColor? {
    guard let cgImage,
          let data = cgImage.dataProvider?.data,
          let bytes = CFDataGetBytePtr(data) else { return nil }
    let bytesPerPixel = cgImage.bitsPerPixel / 8
    let offset = Int(point.y) * cgImage.bytesPerRow + Int(point.x) * bytesPerPixel
    let alphaFirst = [CGImageAlphaInfo.premultipliedFirst, .first, .noneSkipFirst].contains(cgImage.alphaInfo)
    let isLittle = cgImage.bitmapInfo.contains(.byteOrder32Little)
    // BGRA(리틀 엔디언 + 알파 먼저) 또는 RGBA 배열만 다룬다.
    let isBGRA = isLittle && alphaFirst
    let red = bytes[isBGRA ? offset + 2 : offset]
    let green = bytes[offset + 1]
    let blue = bytes[isBGRA ? offset : offset + 2]
    return UIColor(
      red: CGFloat(red) / 255,
      green: CGFloat(green) / 255,
      blue: CGFloat(blue) / 255,
      alpha: 1
    )
  }
}

private extension UIColor {
  func isClose(to other: UIColor) -> Bool {
    let lhs = components
    let rhs = other.components
    return zip(
      lhs,
      rhs
    ).allSatisfy { abs($0 - $1) * 255 <= 4 }
  }

  var components: [CGFloat] {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    getRed(
      &red,
      green: &green,
      blue: &blue,
      alpha: &alpha
    )
    return [red, green, blue]
  }
}
