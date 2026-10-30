//
//  TimetableFeature+Sample.swift
//  Timetable
//
//  Created by FestiCore on 10/30/26.
//

#if DEBUG
  import Foundation

  /// Figma S02 화면과 같은 미리보기·테스트용 데이터
  public extension TimetableFeature.State {
    enum SampleVariant {
      case basic
      case changed
      case overlap
      case unpublished
      case threeStages
      case offline
    }

    static func sample(
      variant: SampleVariant = .basic,
      showsMineOnly: Bool = false
    ) -> Self {
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
          id: "opening",
          artist: "오프닝 크루",
          stageID: "rivet",
          start: 750,
          end: 790
        ),
        TimetableSet(
          id: "noise",
          artist: "노이즈캔디",
          stageID: "rivet",
          start: 780,
          end: 820
        ),
        TimetableSet(
          id: "smoking",
          artist: "스모킹구스",
          stageID: "rivet",
          start: 880,
          end: 928
        ),
        TimetableSet(
          id: "noise-returns",
          artist: "노이즈캔디 리턴즈",
          stageID: "rivet",
          start: 940,
          end: 990
        ),
        TimetableSet(
          id: "lime",
          artist: "라임플래그스",
          stageID: "rivet",
          start: 1020,
          end: 1070
        ),
        TimetableSet(
          id: "headliner",
          artist: "헤드라이너 X",
          stageID: "rivet",
          start: 1290,
          end: 1360
        ),
        TimetableSet(
          id: "rookie",
          artist: "루키 쇼케이스",
          stageID: "wonder",
          start: 720,
          end: 760
        ),
        TimetableSet(
          id: "bluefuse",
          artist: "블루퓨즈",
          stageID: "wonder",
          start: 890,
          end: 935
        ),
        TimetableSet(
          id: "cryingbird",
          artist: "크라잉버드",
          stageID: "wonder",
          start: 955,
          end: 1005
        ),
        TimetableSet(
          id: "encore",
          artist: "앵콜밴드",
          stageID: "wonder",
          start: 1090,
          end: 1140
        ),
        TimetableSet(
          id: "midnight",
          artist: "미드나잇 세션",
          stageID: "wonder",
          start: 1410,
          end: 1530
        ),
      ]

      switch variant {
      case .changed:
        sets[4].previousStart = 1000
        sets[9].previousStart = 1105
      case .threeStages:
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
            start: 760,
            end: 810
          ),
          TimetableSet(
            id: "prism",
            artist: "프리즘",
            stageID: "lake",
            start: 915,
            end: 970
          ),
          TimetableSet(
            id: "deadpony",
            artist: "데드포니",
            stageID: "lake",
            start: 1030,
            end: 1090
          ),
        ]
      case .basic, .overlap, .unpublished, .offline:
        break
      }

      let isUnpublished = variant == .unpublished
      let firstDay = Date(timeIntervalSince1970: 1_786_028_400) // 2026-08-07 00:00 KST
      let days = [("0807", "8/7 금"), ("0808", "8/8 토"), ("0809", "8/9 일")].enumerated().map { index, day in
        TimetableDay(
          id: day.0,
          title: day.1,
          date: firstDay.addingTimeInterval(TimeInterval(index * 24 * 60 * 60)),
          stages: stages,
          sets: index == 0 && !isUnpublished ? sets : []
        )
      }

      var state = Self(
        days: days,
        source: "출처: 주최측 공지 · 확인 10/16 14:00"
      )
      state.mySetIDs = ["noise", "noise-returns", "headliner", "cryingbird"]
      state.showsMineOnly = showsMineOnly
      state.nowMinute = 928
      if isUnpublished {
        state.lineup = [
          TimetableLineupDay(
            id: "0807",
            title: "8/7 (금)",
            artists: ["노이즈캔디", "스모킹구스", "크라잉버드", "앵콜밴드", "헤드라이너 X"]
          ),
          TimetableLineupDay(
            id: "0808",
            title: "8/8 (토)",
            artists: ["라임플래그스", "블루퓨즈", "터치드", "웨이브키즈"]
          ),
        ]
      }
      if variant == .offline {
        state.offlineMessage = "오프라인 · 3분 전 정보"
      }
      return state
    }
  }
#endif
