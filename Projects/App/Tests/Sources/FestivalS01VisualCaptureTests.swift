import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomain
import FestivalDomainInterface
import SwiftUI
import UIKit
import UserNotificationDomainInterface
import XCTest
@testable import Festival

/// 실제 화면을 고정 상태로 렌더한다. 시각 자료 생성용이며 디자인 일치 판정 테스트는 아니다.
/// App이 소유한 로그인 시트(C-1/C-2), 상태 표시줄과 메인 탭은 실기기에서 별도로 검증한다.
@MainActor
final class FestivalS01VisualCaptureTests: XCTestCase {
  func testCaptureLiveBoardStates() async throws {
    for scenario in Scenario.allCases {
      let state = try fixture(scenario)
      // 의도적으로 효과 없는 Store를 사용하여 네트워크와 주기 갱신 없이 View 자체만 캡처한다.
      let store = Store(initialState: state) {
        EmptyReducer<FestivalFeature.State, FestivalFeature.Action>()
      } withDependencies: {
        $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
      }
      try await capture(
        FestivalLiveBoardRouteView(store: store),
        name: scenario.rawValue
      )
      try await capture(
        FestivalLiveBoardRouteView(store: store)
          .safeAreaInset(edge: .bottom) {
            if scenario != .switcher, scenario != .hideGuide {
              FCTabBar(selection: .constant(.live))
            }
          },
        name: "\(scenario.rawValue)-reference-size",
        size: CGSize(
          width: 393,
          height: scenario.referenceHeight
        )
      )
    }
  }

  func testCaptureNotificationStates() async throws {
    for editing in [false, true] {
      var state = NotificationInboxFeature.State()
      state.load = .loaded
      state.items = notifications
      state.isEditing = editing
      state.selectedIDs = editing ? ["notification-0", "notification-1"] : []
      let store = Store(initialState: state) {
        EmptyReducer<NotificationInboxFeature.State, NotificationInboxFeature.Action>()
      } withDependencies: {
        $0.date.now = Date(timeIntervalSince1970: 1_792_475_400)
      }
      try await capture(
        NotificationInboxView(store: store),
        name: editing ? "S01-1-selection" : "S01-1-inbox",
        size: CGSize(
          width: 393,
          height: 852
        )
      )
    }
  }
}

private extension FestivalS01VisualCaptureTests {
  enum Scenario: String, CaseIterable {
    case basic = "S01-A-basic"
    case bearer = "S01-A2-bearer"
    case notification = "S01-A3-notification"
    case switcher = "S01-A4-switcher"
    case beforeOpening = "S01-B-before-opening"
    case loggedOut = "S01-C-logged-out"
    case empty = "S01-D-empty"
    case hideGuide = "S01-D1-hide-guide"
    case finalHour = "S01-E-final-hour"
    case ended = "S01-F-ended"
    case offline = "S01-G-offline"
    case flagsDisabled = "S01-H-flags-disabled"

    var referenceHeight: CGFloat {
      switch self {
      case .basic, .bearer: return 1829
      case .notification, .switcher, .hideGuide: return 852
      case .beforeOpening: return 1666
      case .loggedOut: return 1339
      case .empty: return 1623
      case .finalHour: return 2075
      case .ended: return 1432
      case .offline: return 1865
      case .flagsDisabled: return 1209
      }
    }
  }

  func fixture(_ scenario: Scenario) throws -> FestivalFeature.State {
    let hour: String
    switch scenario {
    case .beforeOpening: hour = "11:30"
    case .finalHour: hour = "21:30"
    case .ended: hour = "22:30"
    default: hour = "15:30"
    }
    let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-20T\(hour):00+09:00"))
    var state = FestivalFeature.State(selectedFestivalID: "visual-festival")
    state.catalog = [.init(
      id: "visual-festival",
      name: "서울 락 페스티벌 2026",
      venue: "올림픽공원",
      firstDate: "2026-10-20",
      lastDate: "2026-10-20",
      packVersion: 1,
      status: "live"
    )]
    let json = packJSON.replacingOccurrences(
      of: "FLAGS_ENABLED",
      with: scenario == .flagsDisabled ? "false" : "true"
    )
    state.selectedPack = try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(json.utf8)
    )
    state.hasStarted = true
    state.hasSession = scenario != .loggedOut
    state.sessionUserID = state.hasSession ? "me" : nil
    state.connection = scenario == .offline ? .offline : .live
    state.liveBoardClockAnchorAt = Date()
    state.liveBoardReceivedAt = Date().addingTimeInterval(scenario == .offline ? -180 : -30)
    state.mySchedule = .init(
      festivalID: "visual-festival",
      setIDs: ["set-now", "set-next"]
    )
    let empty = scenario == .empty || scenario == .hideGuide
    let flag = FestivalLiveBoardSnapshot.Flag(
      id: "flag-1",
      name: "슬램은 즐겁게",
      status: "active",
      zoneID: "main-front",
      activity: "슬램 중",
      thumbnailURL: nil,
      tags: ["슬램", "떼창"],
      updatedAt: now.addingTimeInterval(-60),
      followerCount: 42
    )
    state.liveBoard = .init(
      festivalID: "visual-festival",
      activeFlags: [flag],
      followedFlags: empty ? [] : [flag],
      crew: empty ? nil : .init(
        id: "crew-1",
        name: "오늘도 락앤롤",
        members: [
          .init(
            id: "me",
            nickname: "나",
            state: "active",
            zoneID: "main-front",
            updatedAt: now
          ),
          .init(
            id: "friend",
            nickname: "지민",
            state: "active",
            zoneID: "food",
            updatedAt: now.addingTimeInterval(-60)
          ),
        ],
        ownerID: "me"
      ),
      serverAt: now,
      bearerFlagIDs: scenario == .bearer ? [flag.id] : []
    )
    state.homeDetails = .loaded(
      "visual-festival",
      .init(
        lastShuttleAt: "23:00",
        lastTrainAt: "23:20"
      )
    )
    if scenario == .notification {
      state.notificationUnreadCount = 3
      state.notificationBanner = notifications[0]
    }
    if scenario == .switcher {
      state.festivalSwitcher = .init(
        festivals: [.init(
          id: "visual-festival",
          name: "서울 락 페스티벌 2026",
          subtitle: "오늘 · DAY 1 · 진행 중",
          thumbnailURL: nil
        ), .init(
          id: "visual-next",
          name: "부산 국제 록 페스티벌",
          subtitle: "10/24(토) · 예정",
          thumbnailURL: nil
        )],
        selectedFestivalID: "visual-festival"
      )
    }
    if scenario == .hideGuide {
      state.followGuideAlert = .alert(
        title: "이 안내를 숨길까요?",
        message: "이번 페스티벌 동안 라이브 보드에서 보이지 않아요. 다시 보고 싶으면 마이 > 설정 > 라이브 보드에서 켜거나, 깃발 탭에서 언제든 깃발을 찾을 수 있어요.",
        confirmTitle: "숨기기"
      )
    }
    return state
  }

  var notifications: [UserNotificationItem] {
    return (0..<5).map { index -> UserNotificationItem in
      let timestamp: TimeInterval = 1_792_475_400 - Double(index * 900)
      let readAt: Date? = index > 1 ? Date(timeIntervalSince1970: 1_792_475_400) : nil
      return UserNotificationItem(
        id: "notification-\(index)",
        type: "crew.gather",
        festivalID: "visual-festival",
        title: index == 0 ? "크루가 모이자고 해요" : "팔로우한 깃발이 이동했어요",
        body: index == 0 ? "메인 앞에서 함께 만나요." : "슬램은 즐겁게 · 메인 앞",
        createdAt: Date(timeIntervalSince1970: timestamp),
        readAt: readAt,
        route: nil
      )
    }
  }

  func capture<Content: View>(
    _ content: Content,
    name: String,
    size: CGSize = CGSize(
      width: 390,
      height: 844
    )
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
          width: size.width,
          height: size.height
        ))
      controller.safeAreaRegions = []
      let scene = try XCTUnwrap(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
        "S01 캡처는 앱 호스팅 XCTest의 실제 UIWindowScene이 필요합니다."
      )
      let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
      let window = UIWindow(windowScene: scene)
      window.frame = CGRect(
        origin: .zero,
        size: size
      )
      window.overrideUserInterfaceStyle = .dark
      window.rootViewController = controller
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
      controller.view.frame = window.bounds
      controller.view.setNeedsLayout()
      controller.view.layoutIfNeeded()
      controller.endAppearanceTransition()
      try await Task.sleep(for: .milliseconds(400))
      try writeImage(
        window,
        name: name
      )
      if let scroll = verticalScroll(in: controller.view), scroll.contentSize.height > scroll.bounds.height {
        scroll.setContentOffset(
          CGPoint(
            x: 0,
            y: max(
              0,
              scroll.contentSize.height - scroll.bounds.height
            )
          ),
          animated: false
        )
        try await Task.sleep(for: .milliseconds(100))
        try writeImage(
          window,
          name: "\(name)-bottom"
        )
      }
    }
  }

  func writeImage(
    _ view: UIView,
    name: String
  ) throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    var hierarchyRendered = false
    let image = UIGraphicsImageRenderer(
      bounds: view.bounds,
      format: format
    ).image { _ in
      hierarchyRendered = view.drawHierarchy(
        in: view.bounds,
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
    try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("\(name).png"))
    print("S01_VISUAL_ARTIFACT \(directory.appendingPathComponent("\(name).png").path)")
  }

  func verticalScroll(in view: UIView) -> UIScrollView? {
    if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height {
      return scroll
    }
    return view.subviews.lazy.compactMap { self.verticalScroll(in: $0) }.first
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
      name.contains("switcher") ? 20 : 30,
      "밝은 UI 내용이 없는 캡처: \(name)"
    )
    XCTAssertGreaterThan(
      colors.count,
      8,
      "단색 또는 빈 캡처: \(name)"
    )
  }

  var packJSON: String {
    return #"""
    {"id":"visual-festival","name":"서울 락 페스티벌 2026","flagsEnabled":FLAGS_ENABLED,
    "days":[{"date":"2026-10-20","startsAt":"2026-10-20T13:00:00+09:00","endsAt":"2026-10-20T22:00:00+09:00"}],
    "zones":[{"id":"main-front","name":"메인 앞"},{"id":"food","name":"푸드존"}],
    "source":{"name":"주최측 공지","verifiedAt":"2026-10-20T05:00:00Z"},
    "stages":[{"id":"main","name":"메인"},{"id":"side","name":"사이드"}],
    "sets":[
    {"id":"set-now","stageId":"main","artist":"스모킹구스","startsAt":"2026-10-20T15:00:00+09:00","endsAt":"2026-10-20T15:35:00+09:00"},
    {"id":"set-next","stageId":"main","artist":"노이즈캔디","startsAt":"2026-10-20T15:40:00+09:00","endsAt":"2026-10-20T16:30:00+09:00"},
    {"id":"set-side","stageId":"side","artist":"블루퓨즈","startsAt":"2026-10-20T16:00:00+09:00","endsAt":"2026-10-20T16:40:00+09:00"}]}
    """#
  }
}
