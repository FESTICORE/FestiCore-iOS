import Foundation
import Testing
@testable import FestiCoreUtility

struct FestiCoreDeeplinkTests {
  @Test("위젯 URL은 목록과 축제 라이브 보드만 열고 OAuth URL은 받지 않는다")
  func parsesFestivalURLs() {
    #expect(parse("festicore://festival") == .festivalList)
    #expect(parse("festicore://festival/fst_a") == .festival(id: "fst_a"))
    #expect(parse("festicore://festival/") == nil)
    #expect(parse("festicore://festival/a%2Fb") == nil)
    #expect(parse("festicore://festival/fst?other=1") == nil)
    #expect(parse("com.googleusercontent.apps.sample:/oauth") == nil)
  }

  @Test("깃발 공유 링크는 서버 ID 형식의 깃발 하나만 연다")
  func parsesFlagURLs() {
    #expect(parse("festicore://flag/flg_1") == .flag(id: "flg_1"))
    #expect(parse("FESTICORE://FLAG/flg-A_9") == .flag(id: "flg-A_9"))
    #expect(parse("festicore://flag") == nil)
    #expect(parse("festicore://flag/") == nil)
    #expect(parse("festicore://flag/a.b") == nil)
    #expect(parse("festicore://flag/%ED%98%B8") == nil)
    #expect(parse("festicore://flag/flg_1/extra") == nil)
    #expect(parse("festicore://flag/flg_1?ref=share") == nil)
    #expect(parse("festicore://unknown/flg_1") == nil)
  }

  @Test("공연 알림 링크는 축제와 공연을 함께 연다")
  func parsesSetURL() {
    #expect(parse("festicore://festival/fst_a/set/set_1") == .set(
      festivalID: "fst_a",
      setID: "set_1"
    ))
    #expect(parse("festicore://festival/fst_a/stage/set_1") == nil)
    #expect(parse("festicore://festival/fst_a/set") == nil)
  }

  @Test("대기 저장 문자열은 같은 딥링크로 되돌아온다")
  func encodedRoundTrips() {
    let links: [FestiCoreDeeplink] = [
      .festivalList,
      .festival(id: "fst_a"),
      .flag(id: "flg_1"),
      .set(
        festivalID: "fst_a",
        setID: "set_1"
      )
    ]
    for link in links {
      #expect(FestiCoreDeeplinkParser.parse(urlString: link.encoded) == link)
    }
  }

  @Test("푸시는 deeplink를 먼저 읽고, 없으면 route와 ID로 찾는다")
  func parsesPushPayload() {
    #expect(FestiCoreDeeplinkParser.parse(pushPayload: [
      "deeplink": "festicore://festival/fst_a/set/set_1",
      "route": "/festivals/fst_b/live"
    ]) == .set(
      festivalID: "fst_a",
      setID: "set_1"
    ))
    #expect(FestiCoreDeeplinkParser.parse(pushPayload: ["route": "/festivals/fst_b/checklist"]) == .festival(id: "fst_b"))
    #expect(FestiCoreDeeplinkParser.parse(pushPayload: ["route": "/flags/flg_2"]) == .flag(id: "flg_2"))
    #expect(FestiCoreDeeplinkParser.parse(pushPayload: [
      "route": "/crews/crw_1",
      "festivalId": "fst_c"
    ]) == .festival(id: "fst_c"))
    #expect(FestiCoreDeeplinkParser.parse(pushPayload: ["route": "/"]) == nil)
    #expect(FestiCoreDeeplinkParser.parse(pushPayload: [:]) == nil)
  }

  private func parse(_ value: String) -> FestiCoreDeeplink? {
    return FestiCoreDeeplinkParser.parse(url: URL(string: value)!)
  }
}
