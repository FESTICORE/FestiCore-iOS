import APIEndpoint
import Dependencies
import FestiCoreAuthInterface
import FestiCoreNetworkInterface
import Foundation
import UserNotificationDomainInterface

public struct UserNotificationRepositoryImpl: UserNotificationRepositoryInterface {
  @Dependency(\.networkClient) private var client
  @Dependency(\.authService) private var authService

  public init() {}

  public func notifications(before: String?) async throws -> UserNotificationPage {
    let sessionID = try await requireSession()
    let response = try await client.send(
      UserNotificationRequest.list(before: before, sessionID: sessionID), as: UserNotificationListResponseDTO.self
    )
    guard response.code == "SUCCESS" else { throw UserNotificationError.invalidResponse }
    return try response.data.toDomain()
  }

  public func unreadCount() async throws -> Int {
    let sessionID = try await requireSession()
    let response = try await client.send(
      UserNotificationRequest.unreadCount(sessionID: sessionID), as: UserNotificationCountResponseDTO.self
    )
    guard response.code == "SUCCESS", response.data.unreadCount >= 0 else {
      throw UserNotificationError.invalidResponse
    }
    return response.data.unreadCount
  }

  public func markRead(ids: [String]) async throws {
    guard !ids.isEmpty else { return }
    let sessionID = try await requireSession()
    for batch in ids.chunked(maxCount: 100) {
      _ = try await client.send(
        UserNotificationRequest.read(body: notificationBody(ids: batch), sessionID: sessionID),
        as: FestiCoreEmptyResponse.self
      )
    }
  }

  public func delete(ids: [String]) async throws {
    guard !ids.isEmpty else { return }
    let sessionID = try await requireSession()
    for batch in ids.chunked(maxCount: 100) {
      _ = try await client.send(
        UserNotificationRequest.delete(body: notificationBody(ids: batch), sessionID: sessionID),
        as: FestiCoreEmptyResponse.self
      )
    }
  }

  private func requireSession() async throws -> UUID {
    guard let id = await authService.authenticatedSessionID else { throw UserNotificationError.unauthenticated }
    return id
  }
}

private extension Array {
  func chunked(maxCount: Int) -> [[Element]] {
    stride(from: 0, to: count, by: maxCount).map { Array(self[$0..<Swift.min($0 + maxCount, count)]) }
  }
}
