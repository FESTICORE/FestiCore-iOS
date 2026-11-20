//
//  FestivalOfficialNewsDataDTO+.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/20/26.
//

import FestiCoreUtility
import FestivalDomainInterface
import Foundation

public extension FestivalOfficialNewsDataDTO {
  /// 인스타그램 https 주소만 받는다. 형식이 맞지 않는 게시물은 버린다.
  func toDomain() -> FestivalOfficialNews {
    guard available else { return .unavailable }
    let posts = posts.compactMap { post -> FestivalOfficialNews.Post? in
      guard let permalink = Self.instagramURL(post.permalink),
            let postedAt = post.postedAt.isoDate else { return nil }
      let caption = post.caption?.trimmingCharacters(in: .whitespacesAndNewlines)
      return FestivalOfficialNews.Post(
        id: post.id,
        caption: caption?.isEmpty == false ? caption : nil,
        imageURL: Self.httpsURL(post.imageUrl),
        permalink: permalink,
        postedAt: postedAt
      )
    }
    let account = account.flatMap { account -> FestivalOfficialNews.Account? in
      guard let url = Self.instagramURL(account.url) else { return nil }
      return FestivalOfficialNews.Account(
        username: account.username,
        profileURL: url
      )
    }
    return FestivalOfficialNews(
      isAvailable: true,
      account: account,
      posts: posts
    )
  }

  private static func httpsURL(_ value: String?) -> URL? {
    guard let value, let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
    return url
  }

  private static func instagramURL(_ value: String) -> URL? {
    guard let url = httpsURL(value), ["www.instagram.com", "instagram.com"].contains(url.host ?? "") else { return nil }
    return url
  }
}
