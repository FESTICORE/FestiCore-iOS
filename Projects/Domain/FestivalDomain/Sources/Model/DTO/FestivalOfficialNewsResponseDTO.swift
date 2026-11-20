//
//  FestivalOfficialNewsResponseDTO.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/20/26.
//

import FestiCoreNetworkInterface
import Foundation

public typealias FestivalOfficialNewsResponseDTO = BaseResponseDTO<FestivalOfficialNewsDataDTO>

public struct FestivalOfficialNewsDataDTO: Decodable, Sendable {
  public let festivalId: String
  public let available: Bool
  public let account: Account?
  public let fetchedAt: String?
  public let posts: [Post]

  public struct Account: Decodable, Sendable {
    public let username: String
    public let url: String
  }

  public struct Post: Decodable, Sendable {
    public let id: String
    public let caption: String?
    public let mediaType: String
    public let imageUrl: String?
    public let permalink: String
    public let postedAt: String
  }
}
