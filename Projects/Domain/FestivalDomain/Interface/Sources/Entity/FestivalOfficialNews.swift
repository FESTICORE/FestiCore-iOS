//
//  FestivalOfficialNews.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/20/26.
//

import Foundation

/// 축제 공식 인스타그램 최근 게시물. 서버가 5분마다 받아 둔 것을 그대로 보여 준다.
public struct FestivalOfficialNews: Equatable, Sendable {
  /// 공식 계정이 없거나 서버가 아직 한 번도 받지 못했으면 false다.
  public let isAvailable: Bool
  public let account: Account?
  /// 최신 게시물이 먼저 온다.
  public let posts: [Post]

  public init(
    isAvailable: Bool,
    account: Account?,
    posts: [Post]
  ) {
    self.isAvailable = isAvailable
    self.account = account
    self.posts = posts
  }

  /// 공식 계정이 없거나 아직 받지 못한 상태
  public static let unavailable = FestivalOfficialNews(
    isAvailable: false,
    account: nil,
    posts: []
  )

  /// 라이브 보드에 섹션을 보일지. 게시물이 하나라도 있어야 보인다.
  public var isVisible: Bool {
    return isAvailable && !posts.isEmpty
  }

  public struct Account: Equatable, Sendable {
    public let username: String
    public let profileURL: URL

    public init(
      username: String,
      profileURL: URL
    ) {
      self.username = username
      self.profileURL = profileURL
    }
  }

  public struct Post: Equatable, Sendable, Identifiable {
    public let id: String
    public let caption: String?
    /// 이미지 원본, 영상 썸네일 또는 여러 장 게시물의 첫 이미지. 없으면 캡션만 보인다.
    public let imageURL: URL?
    /// 인스타그램 원본 게시물
    public let permalink: URL
    public let postedAt: Date

    public init(
      id: String,
      caption: String?,
      imageURL: URL?,
      permalink: URL,
      postedAt: Date
    ) {
      self.id = id
      self.caption = caption
      self.imageURL = imageURL
      self.permalink = permalink
      self.postedAt = postedAt
    }
  }
}
