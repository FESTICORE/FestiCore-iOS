import Dependencies
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

struct FestivalLiveBoardPresentationTests {
  @Test("활성 깃발은 최신 갱신 시각 순으로 정렬한다")
  func activeFlagsAreSortedByUpdateTime() {
    let older = FestivalLiveBoardSnapshot.Flag(
      id: "old",
      name: "이전",
      status: "active",
      zoneID: nil,
      activity: nil,
      thumbnailURL: nil,
      updatedAt: Date(timeIntervalSince1970: 100)
    )
    let newer = FestivalLiveBoardSnapshot.Flag(
      id: "new",
      name: "최신",
      status: "active",
      zoneID: nil,
      activity: nil,
      thumbnailURL: nil,
      updatedAt: Date(timeIntervalSince1970: 200)
    )

    #expect(FestivalLiveBoardPresentation.sortedActiveFlags([older, newer]).map(\.id) == ["new", "old"])
  }

  @Test("Figma S01 B: 개장 전 활성 깃발은 앞으로 가장 이른 계획 공연 순, 계획 없는 깃발은 뒤에 최근 업데이트 순")
  func beforeOpeningSortsActiveFlagsByPlannedArrival() throws {
    let pack = try document(packJSON)
    let now = date("2026-10-20T15:10:00+09:00")
    func flag(
      _ id: String,
      updatedAt: TimeInterval,
      plan: [String]
    ) -> FestivalLiveBoardSnapshot.Flag {
      return FestivalLiveBoardSnapshot.Flag(
        id: id,
        name: id,
        status: "active",
        zoneID: nil,
        activity: nil,
        thumbnailURL: nil,
        updatedAt: Date(timeIntervalSince1970: updatedAt),
        plannedSetIDs: plan
      )
    }
    let flags = [
      flag(
        "side",
        updatedAt: 500,
        plan: ["set_side"]
      ),
      // 이미 시작한 공연(set_now)은 도착 예정에서 뺀다.
      flag(
        "next",
        updatedAt: 100,
        plan: ["set_now", "set_next"]
      ),
      flag(
        "none_old",
        updatedAt: 200,
        plan: []
      ),
      flag(
        "none_new",
        updatedAt: 300,
        plan: ["set_unknown"]
      ),
    ]

    #expect(FestivalLiveBoardPresentation.sortedActiveFlagsByArrival(
      flags,
      pack: pack,
      now: now
    ).map(\.id) == ["next", "side", "none_new", "none_old"])
  }

  @Test("서버 시각은 수신 후 흐른 기기 시간만큼 앞으로 간다")
  func serverNowCorrectsDeviceClockSkew() {
    let serverAt = date("2026-10-20T15:00:00+09:00")
    // 기기 시계가 10분 빠르다.
    let receivedAt = serverAt.addingTimeInterval(600)
    #expect(FestivalLiveBoardPresentation.serverNow(
      serverAt: serverAt,
      clockAnchorAt: receivedAt,
      deviceNow: receivedAt
    ) == serverAt)
    #expect(FestivalLiveBoardPresentation.serverNow(
      serverAt: serverAt,
      clockAnchorAt: receivedAt,
      deviceNow: receivedAt.addingTimeInterval(120)
    ) == serverAt.addingTimeInterval(120))
    // 기기 시계가 10분 느려도 같다.
    let slow = serverAt.addingTimeInterval(-600)
    #expect(FestivalLiveBoardPresentation.serverNow(
      serverAt: serverAt,
      clockAnchorAt: slow,
      deviceNow: slow.addingTimeInterval(60)
    ) == serverAt.addingTimeInterval(60))
    #expect(FestivalLiveBoardPresentation.serverNow(
      serverAt: nil,
      clockAnchorAt: slow,
      deviceNow: slow
    ) == slow)
  }

  @Test("상대 시간과 오프라인 문구")
  func relativeAndOfflineText() {
    let now = date("2026-10-20T15:00:00+09:00")
    #expect(FestivalLiveBoardPresentation.relativeTime(
      now.addingTimeInterval(-30),
      now: now
    ) == "방금")
    #expect(FestivalLiveBoardPresentation.relativeTime(
      now.addingTimeInterval(-180),
      now: now
    ) == "3분 전")
    #expect(FestivalLiveBoardPresentation.relativeTime(
      now.addingTimeInterval(-7_200),
      now: now
    ) == "2시간 전")
    #expect(FestivalLiveBoardPresentation.relativeTime(
      nil,
      now: now
    ) == nil)
    #expect(FestivalLiveBoardPresentation.offlineText(
      receivedAt: now.addingTimeInterval(-180),
      deviceNow: now
    )
      == "오프라인 · 3분 전 정보")
    #expect(FestivalLiveBoardPresentation.offlineText(
      receivedAt: nil,
      deviceNow: now
    ) == "오프라인")
    // 갱신 문구는 수신 시각과 같은 기기 시각으로 재므로 서버 시각 보정과 무관하다.
    #expect(FestivalLiveBoardPresentation.updatedText(
      receivedAt: now.addingTimeInterval(-120),
      deviceNow: now
    )
      == "2분 전 업데이트")
    #expect(FestivalLiveBoardPresentation.updatedText(
      receivedAt: nil,
      deviceNow: now
    ) == "시간표 기준")
  }

  @Test("무대 행은 지금·다음 중 있는 쪽만 보이고 내 일정이면 표시한다")
  func stageRowsShowAvailableSlots() throws {
    try withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      let pack = try document(packJSON)
      let rows = FestivalLiveBoardPresentation.stageRows(
        Festival.FestivalLiveBoardSchedule.resolve(
          pack: pack,
          now: date("2026-10-20T15:30:00+09:00")
        ),
        mySetIDs: ["set_next"]
      )
      let main = try #require(rows.first { $0.id == "stg_main" })
      #expect(main.now == .init(
        artist: "스모킹구스",
        time: "15:35 종료"
      ))
      #expect(main.next == .init(
        artist: "노이즈캔디",
        time: "15:40 시작"
      ))
      #expect(main.isMine)
      let side = try #require(rows.first { $0.id == "stg_side" })
      #expect(side.now == nil)
      #expect(side.next == .init(
        artist: "블루퓨즈",
        time: "16:00 시작"
      ))
      #expect(!side.isMine)

      let late = FestivalLiveBoardPresentation.stageRows(
        Festival.FestivalLiveBoardSchedule.resolve(
          pack: pack,
          now: date("2026-10-20T16:10:00+09:00")
        ),
        mySetIDs: []
      )
      #expect(late.first { $0.id == "stg_main" }?.next == nil)
      #expect(late.first { $0.id == "stg_main" }?.now?.artist == "노이즈캔디")
    }
  }

  @Test("내 다음 일정이 있으면 먼저, 없으면 전체 다음 공연")
  func setCardPrefersMySchedule() throws {
    try withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      let pack = try document(packJSON)
      let now = date("2026-10-20T15:30:00+09:00")
      let mine = try #require(FestivalLiveBoardPresentation.setCard(
        pack: pack,
        mySetIDs: ["set_side"],
        isBeforeOpening: false,
        now: now
      ))
      #expect(mine.label == "내 다음 일정")
      #expect(mine.artist == "블루퓨즈")
      #expect(mine.meta == "사이드 · 16:00–16:40")
      #expect(mine.remain == "30분 후")
      #expect(abs(mine.progress - 0.5) < 0.001)

      let next = try #require(FestivalLiveBoardPresentation.setCard(
        pack: pack,
        mySetIDs: [],
        isBeforeOpening: false,
        now: now
      ))
      #expect(next.label == "다음 공연")
      #expect(next.artist == "노이즈캔디")

      let playing = try #require(FestivalLiveBoardPresentation.setCard(
        pack: pack,
        mySetIDs: ["set_now"],
        isBeforeOpening: false,
        now: now
      ))
      #expect(playing.remain == "공연 중")
      #expect(playing.progress > 0 && playing.progress < 1)
    }
  }

  @Test("개장 전에는 카운트다운과 첫 공연 시작 시각을 보인다")
  func beforeOpeningShowsCountdownAndFirstSet() throws {
    try withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      let pack = try document(packJSON)
      let now = date("2026-10-20T10:46:00+09:00")
      let countdown = try #require(FestivalLiveBoardPresentation.countdown(
        pack: pack,
        festival: festival,
        now: now
      ))
      #expect(countdown.time == "2시간 14분")
      let daysAhead = try #require(FestivalLiveBoardPresentation.countdown(
        pack: pack,
        festival: festival,
        now: date("2026-10-02T10:46:00+09:00")
      ))
      #expect(daysAhead.time == "18일 2시간")
      #expect(countdown.sub == "13:00 개장 · 첫 공연 15:00 메인")
      let mine = try #require(FestivalLiveBoardPresentation.setCard(
        pack: pack,
        mySetIDs: ["set_next"],
        isBeforeOpening: true,
        now: now
      ))
      #expect(mine.label == "내 첫 공연")
      #expect(mine.remain == "15:40")
      let first = try #require(FestivalLiveBoardPresentation.setCard(
        pack: pack,
        mySetIDs: [],
        isBeforeOpening: true,
        now: now
      ))
      #expect(first.label == "첫 공연")
      #expect(first.remain == "15:00")
      #expect(FestivalLiveBoardPresentation.countdown(
        pack: pack,
        festival: festival,
        now: date("2026-10-20T13:00:00+09:00")
      ) == nil)
      #expect(FestivalLiveBoardPresentation.dayLine(
        pack: pack,
        festival: festival,
        now: now
      )
        == "DAY 1 · 10.20 (화) · 13:00–23:00")
    }
  }

  @Test("개장 시각과 마지막 1시간 및 종료 시각의 경계를 팩 시간으로 판정한다")
  func phaseUsesPublishedDayBoundaries() throws {
    try withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      let pack = try document(packJSON)
      let opening = date("2026-10-20T13:00:00+09:00")
      let finalHour = date("2026-10-20T22:00:00+09:00")
      let end = date("2026-10-20T23:00:00+09:00")

      #expect(FestivalLiveBoardPresentation.phase(
        pack: pack,
        festival: festival,
        now: opening.addingTimeInterval(-1)
      ) == .beforeOpening(.init(
        time: "0분",
        sub: "13:00 개장 · 첫 공연 15:00 메인"
      )))
      #expect(FestivalLiveBoardPresentation.phase(
        pack: pack,
        festival: festival,
        now: opening
      ) == .live)
      #expect(FestivalLiveBoardPresentation.phase(
        pack: pack,
        festival: festival,
        now: finalHour.addingTimeInterval(-1)
      ) == .live)
      #expect(FestivalLiveBoardPresentation.phase(
        pack: pack,
        festival: festival,
        now: finalHour
      ) == .finalHour(.init(
        time: "1시간 0분",
        sub: "23:00 종료"
      )))
      #expect(FestivalLiveBoardPresentation.phase(
        pack: pack,
        festival: festival,
        now: end.addingTimeInterval(-1)
      ) == .finalHour(.init(
        time: "0분",
        sub: "23:00 종료"
      )))
      #expect(FestivalLiveBoardPresentation.phase(
        pack: pack,
        festival: festival,
        now: end
      ) == .ended)
    }
  }

  @Test("여러 날 축제의 중간날 종료는 축제 종료로 간주하지 않는다")
  func phaseUsesFinalDayOnly() throws {
    try withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      let pack = try document(#"""
        {"id":"fst","days":[
          {"date":"2026-10-20","startsAt":"2026-10-20T13:00:00+09:00","endsAt":"2026-10-20T23:00:00+09:00"},
          {"date":"2026-10-21","startsAt":"2026-10-21T12:00:00+09:00","endsAt":"2026-10-21T22:00:00+09:00"}
        ]}
        """#)
      let festival = FestivalOverview(
        item: .init(
        id: "fst",
        name: "이틀 축제",
        firstDate: "2026-10-20",
        lastDate: "2026-10-21",
        packVersion: 1
      ),
        isCached: true
      )
      #expect(FestivalLiveBoardPresentation.phase(
        pack: pack,
        festival: festival,
        now: date("2026-10-20T22:30:00+09:00")
      ) == .live)
      #expect(FestivalLiveBoardPresentation.phase(
        pack: pack,
        festival: festival,
        now: date("2026-10-21T10:00:00+09:00")
      ) == .beforeOpening(.init(
        time: "2시간 0분",
        sub: "12:00 개장"
      )))
      #expect(FestivalLiveBoardPresentation.phase(
        pack: pack,
        festival: festival,
        now: date("2026-10-21T22:00:00+09:00")
      ) == .ended)
    }
  }

  @Test("게시된 마지막 날짜나 종료 시각이 없으면 종료 상태를 추정하지 않는다")
  func phaseRequiresVerifiedEnd() throws {
    try withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      let noEnd = try document(#"""
        {"id":"fst","days":[{"date":"2026-10-20","startsAt":"2026-10-20T13:00:00+09:00"}]}
        """#)
      let now = date("2026-10-20T23:30:00+09:00")
      #expect(FestivalLiveBoardPresentation.phase(
        pack: nil,
        festival: festival,
        now: now
      ) == .unknown)
      #expect(FestivalLiveBoardPresentation.phase(
        pack: noEnd,
        festival: festival,
        now: now
      ) == .live)

      let missingFinalDay = FestivalOverview(
        item: .init(
        id: "fst",
        name: "이틀 축제",
        firstDate: "2026-10-20",
        lastDate: "2026-10-21",
        packVersion: 1
      ),
        isCached: true
      )
      let firstDayOnly = try document(packJSON)
      #expect(FestivalLiveBoardPresentation.phase(
        pack: firstDayOnly,
        festival: missingFinalDay,
        now: now
      ) == .live)
    }
  }

  @Test("크루 부제는 가장 많은 구역을 고르고 본인·귀가 중을 표시한다")
  func crewSummary() throws {
    let pack = try document(packJSON)
    let now = date("2026-10-20T15:30:00+09:00")
    let crew = FestivalLiveBoardSnapshot.Crew(
      id: "crew",
      name: "락린이들",
      members: [
      .init(
        id: "me",
        nickname: "로이",
        state: "here",
        zoneID: "zon_main",
        updatedAt: now.addingTimeInterval(-20)
      ),
      .init(
        id: "a",
        nickname: "민지",
        state: "eating",
        zoneID: "zon_food",
        updatedAt: now.addingTimeInterval(-420)
      ),
      .init(
        id: "b",
        nickname: "준호",
        state: nil,
        zoneID: "zon_main",
        updatedAt: nil
      ),
      .init(
        id: "c",
        nickname: "한솔",
        state: "leaving",
        zoneID: nil,
        updatedAt: now.addingTimeInterval(-3_600)
      ),
    ]
    )
    let summary = FestivalLiveBoardPresentation.crew(
      crew,
      sessionUserID: "me",
      zoneName: { pack.zoneName(for: $0) },
      now: now
    )
    #expect(summary.title == "내 크루 · 락린이들")
    #expect(summary.subtitle == "4명 · 2명이 메인 앞 근처")
    #expect(summary.members.map(\.isMe) == [true, false, false, false])
    #expect(summary.members.map(\.status) == ["나 여기", "밥", nil, "귀가 중"])
    #expect(summary.members.map(\.time) == ["방금", "7분 전", nil, "1시간 전"])
    #expect(summary.members.map(\.zone) == ["메인 앞", "푸드존", "메인 앞", nil])
    #expect(summary.members.map(\.isLeaving) == [false, false, false, true])
    #expect(FestivalLiveBoardPresentation.crew(
      crew,
      sessionUserID: nil,
      zoneName: { _ in nil },
      now: now
    ).subtitle == "4명")
  }

  @Test("깃발 상태 칩·태그·메타 문구")
  func flagPresentation() throws {
    let pack = try document(packJSON)
    let now = date("2026-10-20T15:30:00+09:00")
    let flag = FestivalLiveBoardSnapshot.Flag(
      id: "flg",
      name: "호락호락",
      status: "ended",
      zoneID: "zon_main",
      activity: "sing",
      thumbnailURL: nil,
      tags: ["slam", "sing", "unknown"],
      updatedAt: now.addingTimeInterval(-300)
    )
    let shown = FestivalLiveBoardPresentation.flag(
      flag,
      zoneName: { pack.zoneName(for: $0) },
      now: now
    )
    #expect(shown.status == .ended)
    #expect(shown.tags == "슬램 · 떼창")
    #expect(shown.meta == "메인 앞 · 떼창")
    #expect(shown.time == "5분 전")
    #expect(FestivalLiveBoardPresentation.flagStatus("scheduled") == nil)
    #expect(FestivalLiveBoardPresentation.flagStatus("resting") == .resting)
    #expect(FestivalLiveBoardPresentation.tagText("resting") == nil)
  }

  @Test("출처 줄은 이름이 있을 때만 그리고 확인 시각을 붙인다")
  func sourceLine() throws {
    let pack = try document(packJSON)
    #expect(FestivalLiveBoardPresentation.sourceLine(pack.source) == "출처: 주최측 공지 · 확인 10/16 14:00")
    let noName = try document(#"{"id":"fst","source":{"verifiedAt":"2026-10-16T05:00:00Z"}}"#)
    #expect(FestivalLiveBoardPresentation.sourceLine(noName.source) == nil)
    let noTime = try document(#"{"id":"fst","source":{"name":"운영팀"}}"#)
    #expect(FestivalLiveBoardPresentation.sourceLine(noTime.source) == "출처: 운영팀")
  }

  private let festival = FestivalOverview(
    item: .init(
      id: "fst",
      name: "원더리벳 2026",
      firstDate: "2026-10-20",
      lastDate: "2026-10-20",
      packVersion: 1
    ),
    isCached: true
  )

  @Test func switcherShowsTodayDayAndCurrentStatus() throws {
    try withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      let pack = try document(packJSON)
      for (
        time,
        status
      ) in [("12:00:00", "시작 전"), ("15:00:00", "진행 중"), ("23:00:00", "종료")] {
        #expect(FestivalLiveBoardPresentation.switcherSubtitle(
          pack: pack,
          festival: festival,
          now: date("2026-10-20T\(time)+09:00")
        ) == "오늘 · DAY 1 \(status)")
      }
    }
  }

  @Test("종료 요약은 날짜 없이 축제 이름과 회차 및 운영 시간을 표시한다")
  func doneSubtitleUsesOperatingHours() throws {
    try withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      let pack = try document(packJSON)
      #expect(FestivalLiveBoardPresentation.doneSubtitle(
        pack: pack,
        festival: festival,
        now: date("2026-10-20T23:00:00+09:00")
      ) == "\(festival.name) DAY 1 · 13:00–23:00")
    }
  }

  @Test("팔로우 깃발은 검증된 축제 최종 종료 경계에서만 오늘 종료로 표시한다")
  func followedFlagEndsAtVerifiedFinalBoundary() throws {
    try withDependencies {
      $0.festivalLiveBoardUseCase = FestivalLiveBoardUseCaseImpl()
    } operation: {
      let pack = try document(packJSON)
      let flag = FestivalLiveBoardSnapshot.Flag(
        id: "flg",
        name: "호락호락",
        status: "active",
        zoneID: nil,
        activity: nil,
        thumbnailURL: nil,
        tags: [],
        updatedAt: nil
      )
      let multiDayFestival = FestivalOverview(
        item: .init(
          id: "fst",
          name: "이틀 축제",
          firstDate: "2026-10-20",
          lastDate: "2026-10-21",
          packVersion: 1
        ),
        isCached: true
      )
      for (
        overview,
        time,
        expected
      ) in [
        (festival, "2026-10-20T22:59:59+09:00", FestivalLiveBoardPresentation.FlagStatus.active),
        (festival, "2026-10-20T23:00:00+09:00", .ended),
        (multiDayFestival, "2026-10-20T23:00:00+09:00", .active),
      ] {
        let now = date(time)
        let ended = FestivalLiveBoardPresentation.phase(
          pack: pack,
          festival: overview,
          now: now
        ) == .ended
        #expect(FestivalLiveBoardPresentation.flag(
          flag,
          zoneName: { _ in return nil },
          now: now,
          festivalEnded: ended
        ).status == expected)
      }
      #expect(flag.status == "active")
    }
  }

  private let packJSON = #"""
    {"id":"fst","flagsEnabled":true,
    "days":[{"date":"2026-10-20","startsAt":"2026-10-20T13:00:00+09:00","endsAt":"2026-10-20T23:00:00+09:00"}],
    "zones":[{"id":"zon_main","name":"메인 앞"},{"id":"zon_food","name":"푸드존"}],
    "source":{"name":"주최측 공지","verifiedAt":"2026-10-16T05:00:00Z"},
    "stages":[{"id":"stg_main","name":"메인"},{"id":"stg_side","name":"사이드"}],
    "sets":[
      {"id":"set_now","stageId":"stg_main","artist":"스모킹구스","startsAt":"2026-10-20T15:00:00+09:00","endsAt":"2026-10-20T15:35:00+09:00"},
      {"id":"set_next","stageId":"stg_main","artist":"노이즈캔디","startsAt":"2026-10-20T15:40:00+09:00","endsAt":"2026-10-20T16:30:00+09:00"},
      {"id":"set_side","stageId":"stg_side","artist":"블루퓨즈","startsAt":"2026-10-20T16:00:00+09:00","endsAt":"2026-10-20T16:40:00+09:00"}
    ]}
    """#

  private func document(_ json: String) throws -> FestivalPackDocument {
    return try JSONDecoder().decode(
      FestivalPackDocument.self,
      from: Data(json.utf8)
    )
  }

  private func date(_ value: String) -> Date {
    return ISO8601DateFormatter().date(from: value)!
  }
}
