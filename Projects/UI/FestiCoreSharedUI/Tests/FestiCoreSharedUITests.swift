import ComposableArchitecture
import SwiftUI
import Testing
@testable import FestiCoreSharedUI

struct FestiCoreSharedUITests {
  @Test @MainActor func sectionHostsFeatureContent() {
    let section = FestiCoreSection("Festival") {
      Text("Upcoming")
    }
    let controller = UIHostingController(rootView: section)
    #expect(controller.view != nil)
  }

  @Test @MainActor func remoteImageCopiesContentModeWithoutChangingOriginal() {
    let original = FCRemoteImage(url: nil)
    let fitted = original.content(.fit)

    #expect(original.contentMode == .fill)
    #expect(fitted.contentMode == .fit)
    #expect(UIHostingController(rootView: fitted).view != nil)
  }

  @Test @MainActor func missingImageKeepsRequestedFrame() {
    let image = FCRemoteImage(url: nil)
      .frame(width: 84, height: 50)
    let controller = UIHostingController(rootView: image)

    #expect(controller.sizeThatFits(in: CGSize(width: 200, height: 200)) == CGSize(width: 84, height: 50))
  }

  @Test @MainActor func fittedRemoteImageKeepsCallerFrame() {
    let image = FCRemoteImage(url: nil)
      .content(.fit)
      .frame(width: 120, height: 80)
    let controller = UIHostingController(rootView: image)

    #expect(controller.sizeThatFits(in: CGSize(width: 200, height: 200)) == CGSize(width: 120, height: 80))
  }


  @Test func svgDataBecomesImage() throws {
    let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="24" height="16"><rect width="24" height="16" fill="black"/></svg>"#
    let image = try #require(makeSVGImage(from: Data(svg.utf8)))

    #expect(image.size == CGSize(width: 24, height: 16))
  }

  @Test func nonSVGDataIsLeftToDefaultProcessor() {
    #expect(makeSVGImage(from: Data([0x89, 0x50, 0x4E, 0x47])) == nil)
  }

  @Test func logoutAlertUsesConfirmationStyle() {
    let alert = FCAlertState.logout()

    #expect(alert.title == "로그아웃할까요?")
    #expect(alert.message == "받은 팩은 이 기기에 그대로 남아 있어요.")
    #expect(alert.confirmTitle == "로그아웃")
    #expect(alert.style == .confirmation)
    #expect(alert == .logout())
  }

  @Test @MainActor func modalHostsPresentedStore() {
    let store = Store(initialState: FCAlertState.logout()) { FCConfirmAlert() }
    let view = Color.clear.fcModal(.constant(store)) { modalStore in
      Text(modalStore.withState(\.title))
    }

    #expect(UIHostingController(rootView: view).view != nil)
  }

  @Test @MainActor func setSheetDrawsArtistImageOnlyWhenURLExists() throws {
    let url = try #require(URL(string: "https://example.com/artist.webp"))
    let original = setSheet()
    let withImage = original.artistImage(url)
    let width = CGSize(width: 393, height: 2_000)

    #expect(original.artistImageURL == nil)
    #expect(withImage.artistImageURL == url)
    #expect(withImage.artistImage(nil).artistImageURL == nil)
    // 사진 칸(48pt)이 한 줄 제목보다 높아 사진이 있을 때만 시트가 길어진다.
    let plainHeight = UIHostingController(rootView: original).sizeThatFits(in: width).height
    let imageHeight = UIHostingController(rootView: withImage).sizeThatFits(in: width).height
    #expect(imageHeight > plainHeight)
  }

  @Test(
    "내 일정 토글로 태그가 나타나고 사라져도 시트 높이가 같다",
    arguments: [
      FCSetSheet.State.default,
      .overlap(warning: "달담과 35분 겹쳐요"),
    ]
  )
  @MainActor
  func setSheetHeightStaysWhenScheduleToggles(state: FCSetSheet.State) {
    let heights = [false, true].map { isScheduled in
      let sheet = FCSetSheet(
        artist: "윤마치",
        stage: "리벳 스테이지",
        time: "17:00–17:50 · 50분",
        relativeTime: "1시간 후",
        isScheduled: .constant(isScheduled)
      )
      .state(state)
      return UIHostingController(rootView: sheet).sizeThatFits(in: CGSize(
        width: 393,
        height: CGFloat.greatestFiniteMagnitude
      )).height
    }

    #expect(heights[0] > 0)
    #expect(heights[0] == heights[1])
  }

  private func setSheet() -> FCSetSheet {
    FCSetSheet(
      artist: "가수",
      stage: "메인 스테이지",
      time: "17:00–17:50 · 50분",
      relativeTime: "1시간 후",
      isScheduled: .constant(false)
    )
  }
}
