//
//  FestivalOfficialNewsMapperTests.swift
//  FestivalDomainTests
//
//  Created by FestiCore on 11/20/26.
//

import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalOfficialNewsMapperTests {
  @Test func availableNewsKeepsOnlyInstagramPostsWithValidTime() throws {
    let data = try JSONDecoder().decode(
      FestivalOfficialNewsDataDTO.self,
      from: Data(#"""
      {"festivalId":"fst","available":true,
       "account":{"username":"wonderliivet","url":"https://www.instagram.com/wonderliivet/"},
       "fetchedAt":"2026-11-20T09:00:00.000Z",
       "posts":[
        {"id":"1","caption":"  타임테이블 안내  ","mediaType":"IMAGE","imageUrl":"https://cdn.example/1.jpg",
         "permalink":"https://www.instagram.com/p/AAA/","postedAt":"2026-11-20T08:55:00.000Z"},
        {"id":"2","caption":"   ","mediaType":"VIDEO","imageUrl":"http://cdn.example/2.jpg",
         "permalink":"https://www.instagram.com/p/BBB/","postedAt":"2026-11-20T08:00:00Z"},
        {"id":"3","caption":null,"mediaType":"IMAGE","imageUrl":null,
         "permalink":"https://evil.example/p/CCC/","postedAt":"2026-11-20T07:00:00Z"},
        {"id":"4","caption":null,"mediaType":"IMAGE","imageUrl":null,
         "permalink":"https://www.instagram.com/p/DDD/","postedAt":"not-a-date"}
       ]}
      """#.utf8)
    )

    let news = data.toDomain()

    #expect(news.isAvailable)
    #expect(news.isVisible)
    #expect(news.account?.username == "wonderliivet")
    #expect(news.posts.map(\.id) == ["1", "2"])
    #expect(news.posts[0].caption == "타임테이블 안내")
    #expect(news.posts[0].imageURL == URL(string: "https://cdn.example/1.jpg"))
    #expect(news.posts[0].postedAt == ISO8601DateFormatter().date(from: "2026-11-20T08:55:00Z"))
    // http 이미지는 버리고 빈 캡션은 nil로 둔다.
    #expect(news.posts[1].imageURL == nil)
    #expect(news.posts[1].caption == nil)
  }

  @Test func unavailableNewsIsHidden() throws {
    let data = try JSONDecoder().decode(
      FestivalOfficialNewsDataDTO.self,
      from: Data(#"""
      {"festivalId":"fst","available":false,"account":null,"fetchedAt":null,"posts":[]}
      """#.utf8)
    )

    let news = data.toDomain()

    #expect(news == .unavailable)
    #expect(!news.isVisible)
  }
}
