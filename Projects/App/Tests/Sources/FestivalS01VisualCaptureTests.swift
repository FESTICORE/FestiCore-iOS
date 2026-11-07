import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestivalDomain
import FestivalDomainInterface
import SwiftUI
import TimetableDomainInterface
import UIKit
import UserNotificationDomainInterface
import XCTest
@testable import Festival
@testable import Timetable

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

  func testCaptureTimetableStates() async throws {
    for scenario in TimetableScenario.allCases {
      let state = timetableFixture(scenario)
      if scenario == .overlap {
        XCTAssertEqual(
          state.overlaps.count,
          1
        )
        XCTAssertEqual(
          state.overlaps.first?.minutes,
          35
        )
        XCTAssertEqual(
          state.visibleOverlaps.count,
          1
        )
      } else if scenario == .basic || scenario == .mineOnly || scenario == .changed {
        XCTAssertEqual(
          state.overlaps.count,
          1
        )
        XCTAssertTrue(state.visibleOverlaps.isEmpty)
      }
      let store = Store(initialState: state) {
        EmptyReducer<TimetableFeature.State, TimetableFeature.Action>()
      }
      try await capture(
        TimetableView(store: store)
          .safeAreaInset(edge: .bottom) {
            FCTabBar(selection: .constant(.timetable))
          },
        name: scenario.rawValue,
        size: CGSize(
          width: 393,
          height: 852
        )
      )
    }
  }
}

private extension FestivalS01VisualCaptureTests {
  enum TimetableScenario: String, CaseIterable {
    case basic = "S02-A-basic"
    case mineOnly = "S02-B-mine-only"
    case changed = "S02-C-changed"
    case overlap = "S02-D-overlap"
    case unpublished = "S02-E-unpublished"
    case threeStages = "S02-F-three-stages"
    case offline = "S02-G-offline"
  }

  func timetableFixture(_ scenario: TimetableScenario) -> TimetableFeature.State {
    var stages = [
      TimetableStage(
        id: "rivet",
        name: "리벳 스테이지"
      ),
      TimetableStage(
        id: "wonder",
        name: "원더 스테이지"
      ),
    ]
    var sets = [
      TimetableSet(
        id: "touched",
        artist: "터치드",
        stageID: "rivet",
        start: 880,
        end: 928
      ),
      TimetableSet(
        id: "one-oak",
        artist: "원오크로",
        stageID: "rivet",
        start: 940,
        end: 990
      ),
      TimetableSet(
        id: "yoonmachi-rivet",
        artist: "윤마치",
        stageID: "rivet",
        start: 1020,
        end: 1070
      ),
      TimetableSet(
        id: "lucy",
        artist: "LUCY",
        stageID: "wonder",
        start: 890,
        end: 935
      ),
      TimetableSet(
        id: "daldam",
        artist: "달담",
        stageID: "wonder",
        start: 955,
        end: 1005
      ),
      TimetableSet(
        id: "headliner-rivet",
        artist: "헤드라이너",
        stageID: "rivet",
        start: 1170,
        end: 1220
      ),
      TimetableSet(
        id: "afterparty-wonder",
        artist: "애프터파티",
        stageID: "wonder",
        start: 1260,
        end: 1320
      ),
    ]
    if scenario == .changed {
      sets[1].previousStart = 970
      sets[2].previousStart = 1000
    }
    if scenario == .threeStages {
      stages.append(
        TimetableStage(
          id: "lake",
          name: "레이크 스테이지"
        )
      )
      sets += [
        TimetableSet(
          id: "wavekids",
          artist: "웨이브키즈",
          stageID: "lake",
          start: 900,
          end: 950
        ),
        TimetableSet(
          id: "prism",
          artist: "프리즘",
          stageID: "lake",
          start: 975,
          end: 1020
        ),
        TimetableSet(
          id: "deadpony",
          artist: "데드포니",
          stageID: "lake",
          start: 1050,
          end: 1100
        ),
      ]
    }
    let isUnpublished = scenario == .unpublished
    let firstDay = Date(timeIntervalSince1970: 1_786_028_400)
    let days = [("0807", "8/7 금"), ("0808", "8/8 토"), ("0809", "8/9 일")]
      .enumerated()
      .map { index, day in
        TimetableDay(
          id: day.0,
          title: day.1,
          date: firstDay.addingTimeInterval(TimeInterval(index * 24 * 60 * 60)),
          stages: stages,
          sets: index == 0 && !isUnpublished ? sets : []
        )
      }
    var state = TimetableFeature.State(
      days: days,
      source: "출처: 주최측 공지 · 확인 10/16 14:00"
    )
    switch scenario {
    case .overlap:
      state.mySetIDs = ["one-oak", "daldam"]
    case .mineOnly:
      state.mySetIDs = ["one-oak", "daldam", "headliner-rivet", "afterparty-wonder"]
    case .changed:
      state.mySetIDs = ["one-oak", "daldam", "headliner-rivet", "afterparty-wonder"]
    default:
      state.mySetIDs = ["one-oak", "daldam", "headliner-rivet", "afterparty-wonder"]
    }
    state.showsMineOnly = scenario == .mineOnly
    state.shouldShowOverlapWarning = scenario == .overlap
    state.nowMinute = 928
    if isUnpublished {
      state.contentStatus = .unpublished
      state.lineup = [
        TimetableLineupDay(
          id: "0807",
          title: "8/7 (금)",
          artists: ["한로로", "터치드", "달담", "AKMU", "데이브레이크"]
        ),
        TimetableLineupDay(
          id: "0808",
          title: "8/8 (토)",
          artists: ["라임플래그스", "블루퓨즈", "터치드", "웨이브키즈"]
        ),
      ]
    }
    if scenario == .offline {
      state.offlineMessage = "오프라인 · 3분 전 정보"
    }
    return state
  }

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
    let time: String
    switch scenario {
    case .beforeOpening: time = "11:30:00"
    case .finalHour: time = "21:30:00"
    case .ended: time = "23:30:00"
    default: time = "15:27:30"
    }
    let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-17T\(time)+09:00"))
    var state = FestivalFeature.State(selectedFestivalID: "visual-festival")
    state.catalog = [.init(
      id: "visual-festival",
      name: "원더리벳 2026",
      venue: "올림픽공원",
      firstDate: "2026-10-17",
      lastDate: "2026-10-17",
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
      setIDs: ["next-hanroro"]
    )
    let empty = scenario == .empty || scenario == .hideGuide
    let followedFlags = [
      flag(
        "follow-horak",
        name: "호락호락",
        zoneID: "rivet-left",
        activity: "slam",
        tags: ["slam", "sing"],
        updatedAt: now.addingTimeInterval(-5 * 60)
      ),
      flag(
        "follow-chorus",
        name: "떼창단",
        zoneID: "wonder-left",
        activity: "sing",
        tags: ["sing"],
        updatedAt: now.addingTimeInterval(-8 * 60)
      ),
      flag(
        "follow-train",
        name: "기차놀이",
        zoneID: "food",
        activity: "train",
        tags: ["train"],
        updatedAt: now.addingTimeInterval(-12 * 60)
      ),
    ]
    let activeFlags = [
      flag(
        "active-encore",
        name: "앵콜원정대",
        zoneID: "rivet-front",
        activity: "sing",
        tags: ["sing"],
        updatedAt: now.addingTimeInterval(-2 * 60)
      ),
      flag(
        "active-pink",
        name: "핑크닉은락",
        zoneID: "wonder-front",
        activity: "slam",
        tags: ["slam"],
        updatedAt: now.addingTimeInterval(-4 * 60),
        status: "resting"
      ),
      flag(
        "active-headbanger",
        name: "헤드뱅어",
        zoneID: "rivet-center",
        activity: "slam",
        tags: ["slam"],
        updatedAt: now.addingTimeInterval(-6 * 60)
      ),
      flag(
        "active-rock",
        name: "락앤롤베이비",
        zoneID: "food",
        activity: "train",
        tags: ["train"],
        updatedAt: now.addingTimeInterval(-9 * 60),
        status: "resting"
      ),
    ]
    state.liveBoard = .init(
      festivalID: "visual-festival",
      activeFlags: empty ? [] : activeFlags,
      followedFlags: empty ? [] : followedFlags,
      crew: empty ? nil : .init(
        id: "crew-1",
        name: "락인들",
        members: [
          .init(
            id: "me",
            nickname: "로이",
            state: "here",
            zoneID: "rivet-left",
            updatedAt: now
          ),
          .init(
            id: "minji",
            nickname: "민지",
            state: "eating",
            zoneID: "food",
            updatedAt: now.addingTimeInterval(-7 * 60)
          ),
          .init(
            id: "junho",
            nickname: "준호",
            state: "toilet",
            zoneID: "wonder-back",
            updatedAt: now.addingTimeInterval(-12 * 60)
          ),
          .init(
            id: "hansol",
            nickname: "한솔",
            state: "leaving",
            zoneID: "gate",
            updatedAt: now.addingTimeInterval(-60 * 60)
          ),
        ],
        ownerID: "me"
      ),
      serverAt: now,
      bearerFlagIDs: scenario == .bearer ? [activeFlags[0].id] : []
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
          name: "원더리벳 2026",
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

  func flag(
    _ id: String,
    name: String,
    zoneID: String,
    activity: String,
    tags: [String],
    updatedAt: Date,
    status: String = "active"
  ) -> FestivalLiveBoardSnapshot.Flag {
    return FestivalLiveBoardSnapshot.Flag(
      id: id,
      name: name,
      status: status,
      zoneID: zoneID,
      activity: activity,
      thumbnailURL: nil,
      tags: tags,
      updatedAt: updatedAt,
      followerCount: 42
    )
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
    XCTAssertGreaterThanOrEqual(
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
    {"id":"visual-festival","name":"원더리벳 2026","flagsEnabled":FLAGS_ENABLED,
    "days":[{"date":"2026-10-17","startsAt":"2026-10-17T12:00:00+09:00","endsAt":"2026-10-17T23:00:00+09:00"}],
    "zones":[{"id":"rivet","name":"리벳 스테이지"},{"id":"wonder","name":"원더 스테이지"},{"id":"rivet-left","name":"리벳 앞 왼쪽"},{"id":"wonder-left","name":"원더 스테이지 왼쪽"},{"id":"rivet-front","name":"리벳 앞"},{"id":"wonder-front","name":"원더 앞"},{"id":"rivet-center","name":"리벳 중앙"},{"id":"wonder-back","name":"원더 스테이지 뒤"},{"id":"food","name":"푸드존"},{"id":"gate","name":"정문 밖"}],
    "source":{"name":"주최측 공지","verifiedAt":"2026-10-16T05:00:00Z"},
    "stages":[{"id":"rivet","name":"리벳 스테이지"},{"id":"wonder","name":"원더 스테이지"}],
    "sets":[
    {"id":"set-now","stageId":"rivet","artist":"터치드","startsAt":"2026-10-17T14:40:00+09:00","endsAt":"2026-10-17T15:28:00+09:00"},
    {"id":"next-hanroro","stageId":"rivet","artist":"한로로","startsAt":"2026-10-17T15:40:00+09:00","endsAt":"2026-10-17T16:30:00+09:00"},
    {"id":"wonder-now","stageId":"wonder","artist":"LUCY","startsAt":"2026-10-17T14:50:00+09:00","endsAt":"2026-10-17T15:35:00+09:00"},
    {"id":"next-yoonmachi","stageId":"wonder","artist":"윤마치","startsAt":"2026-10-17T15:55:00+09:00","endsAt":"2026-10-17T16:45:00+09:00"}]}
    """#
  }
}
