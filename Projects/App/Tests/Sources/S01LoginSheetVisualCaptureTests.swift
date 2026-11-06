import ComposableArchitecture
import FeatureAssembly
import FestivalDomain
import FestivalDomainInterface
import SwiftUI
import TCAFlow
import UIKit
import XCTest
@testable import FestiCore

/// 실제 MainTabView의 인증 시트 합성. 고정 상태 이미지이며 인증/라우팅 동작 검증은 별도다.
@MainActor
final class S01LoginSheetVisualCaptureTests: XCTestCase {
  func testCaptureCrewAndFollowLoginSheets() async throws {
    let contexts: [LoginFeature.State.Context?] = [nil, .crew, .follow]
    for context in contexts {
      var state = MainTabCoordinator.State()
      var board = FestivalFeature.State(selectedFestivalID: "visual-festival")
      board.catalog = [.init(
        id: "visual-festival",
        name: "서울 락 페스티벌 2026",
        venue: "올림픽공원",
        firstDate: "2026-10-20",
        lastDate: "2026-10-20",
        packVersion: 1
      )]
      // Festival 시각 fixture와 같은 공연을 사용하되 테스트 타깃 경계상 최소 JSON만 둔다.
      board.selectedPack = try JSONDecoder().decode(
        FestivalPackDocument.self,
        from: Data(packJSON.utf8)
      )
      board.hasStarted = true
      board.connection = .live
      board.liveBoardClockAnchorAt = Date()
      board.liveBoardReceivedAt = Date()
      board.liveBoard = .init(
        festivalID: "visual-festival",
        activeFlags: [],
        followedFlags: [],
        crew: nil,
        serverAt: ISO8601DateFormatter().date(from: "2026-10-20T15:30:00+09:00")
      )
      state.festivalState.routes.push(.liveBoard(board))
      state.authFlow.presentation = context == nil ? nil : .login
      state.loginState.context = context ?? .crew
      let store = Store(initialState: state) {
        EmptyReducer<MainTabCoordinator.State, MainTabCoordinator.Action>()
      } withDependencies: {
        $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
      }
      try await capture(
        MainTabView(store: store),
        name: context == nil ? "S01-C-main-tab-baseline" : (context == .crew ? "S01-C1-crew-login" : "S01-C2-follow-login")
      )
    }
  }
}

private extension S01LoginSheetVisualCaptureTests {
  func capture<Content: View>(
    _ content: Content,
    name: String
  ) async throws {
    try await withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      // 실제 scene의 safe-area는 작은 기준 창에 오른쪽 inset을 추가할 수 있다.
      // 시스템 inset 대신 기준 프레임의 여백을 SwiftUI 레이아웃에 직접 제공한다.
      let controller = UIHostingController(rootView: content
        .environment(
          \.colorScheme,
          .dark
        )
        .padding(
          .top,
          59
        )
        .padding(
          .bottom,
          34
        )
        .frame(
          width: 393,
          height: 852
        ))
      controller.safeAreaRegions = []
      let scene = try XCTUnwrap(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
        "S01 캡처는 앱 호스팅 XCTest의 실제 UIWindowScene이 필요합니다."
      )
      let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
      let window = UIWindow(windowScene: scene)
      // UIWindow를 scene보다 줄이면 UIKit navigation 자식에 잘린 영역만큼 inset이 전파된다.
      // 실제 창은 native 크기, 캡처할 자식 view만 디자인 기준 크기로 배치한다.
      window.frame = scene.coordinateSpace.bounds
      let container = UIViewController()
      container.view.backgroundColor = .black
      container.addChild(controller)
      container.view.addSubview(controller.view)
      controller.didMove(toParent: container)
      window.overrideUserInterfaceStyle = .dark
      window.rootViewController = container
      window.makeKeyAndVisible()
      defer {
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
      }
      controller.beginAppearanceTransition(
        true,
        animated: false
      )
      controller.view.frame = CGRect(
        x: 0,
        y: 0,
        width: 393,
        height: 852
      )
      controller.view.setNeedsLayout()
      controller.view.layoutIfNeeded()
      controller.endAppearanceTransition()
      try await Task.sleep(for: .milliseconds(600))
      print("S01_CAPTURE_GEOMETRY \(name) scene=\(scene.coordinateSpace.bounds) window=\(window.bounds) host=\(controller.view.frame) inset=\(controller.view.safeAreaInsets)")
      logGeometry(controller)
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      var hierarchyRendered = false
      let image = UIGraphicsImageRenderer(
        bounds: controller.view.bounds,
        format: format
      ).image { _ in
        hierarchyRendered = controller.view.drawHierarchy(
          in: controller.view.bounds,
          afterScreenUpdates: true
        )
      }
      let attachment = XCTAttachment(image: image)
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
      XCTAssertTrue(
        hierarchyRendered,
        "UIKit render server가 화면 계층을 렌더하지 못했습니다: \(name)"
      )
      try assertVisibleContent(
        image,
        name: name
      )
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FestiCore-S01-Visual")
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      let file = directory.appendingPathComponent("\(name).png")
      try XCTUnwrap(image.pngData()).write(to: file)
      print("S01_VISUAL_ARTIFACT \(file.path)")
    }
  }

  /// 검은 캡처/단색 배경을 성공으로 오인하지 않도록 실제 밝은 텍스트와 색상 분포를 확인한다.
  func assertVisibleContent(
    _ image: UIImage,
    name: String
  ) throws {
    let cgImage = try XCTUnwrap(image.cgImage)
    let width = 128
    let height = 128
    var pixels = [UInt8](
      repeating: 0,
      count: width * height * 4
    )
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    try pixels.withUnsafeMutableBytes { buffer in
      let context = try XCTUnwrap(CGContext(
        data: buffer.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ))
      context.draw(
        cgImage,
        in: CGRect(
          x: 0,
          y: 0,
          width: width,
          height: height
        )
      )
    }
    var brightPixels = 0
    var colors: Set<Int> = []
    for offset in stride(
      from: 0,
      to: pixels.count,
      by: 4
    ) {
      let red = Int(pixels[offset])
      let green = Int(pixels[offset + 1])
      let blue = Int(pixels[offset + 2])
      if [red, green, blue].max()! > 150 { brightPixels += 1 }
      colors.insert((red / 16) << 8 | (green / 16) << 4 | blue / 16)
    }
    XCTAssertGreaterThan(
      brightPixels,
      30,
      "밝은 UI 내용이 없는 캡처: \(name)"
    )
    XCTAssertGreaterThan(
      colors.count,
      8,
      "단색 또는 빈 캡처: \(name)"
    )
  }

  func logGeometry(_ controller: UIViewController) {
    print("S01_CAPTURE_CONTROLLER \(type(of: controller)) frame=\(controller.view.frame) safeArea=\(controller.view.safeAreaInsets)")
    for child in controller.children { logGeometry(child) }
  }

  var packJSON: String {
    return #"""
    {"id":"visual-festival","name":"서울 락 페스티벌 2026","flagsEnabled":true,
    "days":[{"date":"2026-10-20","startsAt":"2026-10-20T13:00:00+09:00","endsAt":"2026-10-20T22:00:00+09:00"}],
    "stages":[{"id":"main","name":"메인"},{"id":"side","name":"사이드"}],
    "sets":[
    {"id":"set-now","stageId":"main","artist":"스모킹구스","startsAt":"2026-10-20T15:00:00+09:00","endsAt":"2026-10-20T15:35:00+09:00"},
    {"id":"set-next","stageId":"main","artist":"노이즈캔디","startsAt":"2026-10-20T15:40:00+09:00","endsAt":"2026-10-20T16:30:00+09:00"},
    {"id":"set-side","stageId":"side","artist":"블루퓨즈","startsAt":"2026-10-20T16:00:00+09:00","endsAt":"2026-10-20T16:40:00+09:00"}]}
    """#
  }
}
