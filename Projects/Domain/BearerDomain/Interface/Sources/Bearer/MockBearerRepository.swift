//
//  MockBearerRepository.swift
//  BearerDomain
//
//  Created by FestiCore on 11/3/26.
//

import Foundation
import IssueReporting

/// 주입하지 않은 기수 저장소. 호출하면 테스트 이슈를 남기고 실패한다.
public struct MockBearerRepository: BearerRepositoryInterface {
  private let dependencyName: String

  public init(dependencyName: String = "bearerRepository") {
    self.dependencyName = dependencyName
  }

  public func claim(festivalID: String, code: String) async throws -> BearerClaim {
    throw unregistered()
  }

  public func fetchBoard(flagID: String) async throws -> BearerBoard {
    throw unregistered()
  }

  public func updateProfile(flagID: String, change: BearerProfileChange) async throws -> BearerFlagProfile {
    throw unregistered()
  }

  public func uploadPhoto(flagID: String, jpegData: Data) async throws -> BearerFlagPhoto {
    throw unregistered()
  }

  public func sendStatus(flagID: String, request: BearerStatusRequest) async throws -> BearerFlagStatus {
    throw unregistered()
  }

  public func inviteCoBearer(flagID: String) async throws -> BearerInvite {
    throw unregistered()
  }

  public func removeCoBearer(flagID: String, userID: String) async throws {
    throw unregistered()
  }

  private func unregistered() -> BearerError {
    reportIssue("\(dependencyName) 미등록")
    return .unavailable
  }
}
