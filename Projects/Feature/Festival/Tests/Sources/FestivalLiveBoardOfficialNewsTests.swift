//
//  FestivalLiveBoardOfficialNewsTests.swift
//  FestivalTests
//
//  Created by FestiCore on 11/20/26.
//

import ComposableArchitecture
import FestivalDomainInterface
import Foundation
import Testing
@testable import Festival

@MainActor
struct FestivalLiveBoardOfficialNewsTests {
  @Test("라이브 보드를 감시하면 공식 소식을 받고, 5분 뒤 바뀐 소식만 다시 반영한다")
  func watchLoadsOfficialNewsAndRefreshesOnlyWhenChanged() async {
    let clock = TestClock()
    let responses = LockIsolated<[FestivalOfficialNews]>([
      firstNews,
      firstNews,
      secondNews,
    ])
    let calls = LockIsolated(0)
    let store = TestStore(initialState: watchingState()) {
      FestivalLiveBoardFeature()
    } withDependencies: {
      $0.festivalLiveBoardUseCase = MockFestivalLiveBoardUseCase(
        liveBoard: { _ in
          return emptyBoard
        },
        officialNews: { festivalID in
          #expect(festivalID == "fst")
          calls.withValue { $0 += 1 }
          return responses.withValue { $0.isEmpty ? secondNews : $0.removeFirst() }
        }
      )
      $0.continuousClock = clock
      $0.date = .constant(Date(timeIntervalSince1970: 1_000))
    }
    store.exhaustivity = .off

    await store.send(.view(.watchRequested(
      festivalID: "fst",
      generation: 0
    )))
    await store.receive(\.inner.officialNewsLoaded) {
      $0.officialNews = firstNews
      $0.officialNewsFestivalID = "fst"
    }
    #expect(store.state.visibleOfficialNews == firstNews)

    // 같은 소식은 다시 보내지 않는다.
    await clock.advance(by: .seconds(300))
    #expect(calls.value == 2)
    #expect(store.state.officialNews == firstNews)

    await clock.advance(by: .seconds(300))
    await store.receive(\.inner.officialNewsLoaded) {
      $0.officialNews = secondNews
    }
    #expect(calls.value == 3)

    await store.send(.view(.stopped))
    await store.finish()
  }

  @Test("공식 계정이 없거나 불러오지 못하면 보내지 않고 이미 보이던 소식을 유지한다")
  func unavailableOrFailingNewsDoesNotReplaceVisibleNews() async {
    let clock = TestClock()
    let shouldFail = LockIsolated(false)
    var state = watchingState()
    state.officialNews = firstNews
    state.officialNewsFestivalID = "fst"
    let store = TestStore(initialState: state) {
      FestivalLiveBoardFeature()
    } withDependencies: {
      $0.festivalLiveBoardUseCase = MockFestivalLiveBoardUseCase(
        liveBoard: { _ in
          return emptyBoard
        },
        officialNews: { _ in
          if shouldFail.value { throw FestivalLiveBoardError.invalidResponse }
          return .unavailable
        }
      )
      $0.continuousClock = clock
      $0.date = .constant(Date(timeIntervalSince1970: 1_000))
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.watchRequested(
      festivalID: "fst",
      generation: 0
    )))
    shouldFail.setValue(true)
    await clock.advance(by: .seconds(300))
    #expect(store.state.officialNews == firstNews)

    await store.send(.view(.stopped))
    await store.finish()
  }

  @Test("이전 축제의 소식은 다른 축제를 고르면 보이지 않는다")
  func newsOfAnotherFestivalIsHidden() {
    var state = watchingState()
    state.officialNews = firstNews
    state.officialNewsFestivalID = "fst_old"
    #expect(state.visibleOfficialNews == nil)
    state.officialNewsFestivalID = "fst"
    #expect(state.visibleOfficialNews == firstNews)
  }

  @Test("다른 축제나 계정 세대의 늦은 응답은 버린다")
  func staleResponseIsIgnored() async {
    let store = TestStore(initialState: watchingState()) {
      FestivalLiveBoardFeature()
    }

    await store.send(.inner(.officialNewsLoaded(
      "fst_old",
      generation: 0,
      firstNews
    )))
    await store.send(.inner(.officialNewsLoaded(
      "fst",
      generation: 1,
      firstNews
    )))
  }

  @Test("게시물을 누르면 인스타그램 원본 게시물을 연다")
  func tappingPostOpensPermalink() async throws {
    let opened = LockIsolated<[URL]>([])
    let store = TestStore(initialState: watchingState()) {
      FestivalLiveBoardFeature()
    } withDependencies: {
      $0.openURL = .init { url in
        opened.withValue { $0.append(url) }
        return true
      }
    }
    let permalink = try #require(URL(string: "https://www.instagram.com/p/AAA/"))

    await store.send(.view(.officialNewsPostTapped(permalink)))
    await store.finish()
    #expect(opened.value == [permalink])
  }
}

private func watchingState() -> FestivalLiveBoardFeature.State {
  var state = FestivalLiveBoardFeature.State()
  state.selectedFestivalID = "fst"
  state.accountGeneration = 0
  return state
}

private let emptyBoard = FestivalLiveBoardSnapshot(
  festivalID: "fst",
  activeFlags: [],
  followedFlags: [],
  crew: nil
)

private let firstNews = FestivalOfficialNews(
  isAvailable: true,
  account: nil,
  posts: [
    .init(
      id: "1",
      caption: "타임테이블 안내",
      imageURL: URL(string: "https://cdn.example/1.jpg"),
      permalink: URL(string: "https://www.instagram.com/p/AAA/")!,
      postedAt: Date(timeIntervalSince1970: 900)
    ),
  ]
)

private let secondNews = FestivalOfficialNews(
  isAvailable: true,
  account: nil,
  posts: [
    .init(
      id: "2",
      caption: "입장 안내",
      imageURL: nil,
      permalink: URL(string: "https://www.instagram.com/p/BBB/")!,
      postedAt: Date(timeIntervalSince1970: 1_200)
    ),
  ] + firstNews.posts
)
