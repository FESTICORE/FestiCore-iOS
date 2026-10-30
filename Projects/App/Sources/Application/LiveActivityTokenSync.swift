import ActivityKit
import CoreAssembly
import FestiCoreDeviceInterface
import FestiCoreLiveActivity
import Foundation

@MainActor
final class LiveActivityTokenSync {
  struct Source {
    var activities: () -> [FestiCoreFestivalActivitySummary]
    var changes: () -> AsyncStream<Void>
    var pushTokenUpdates: (String) -> AsyncStream<FestiCoreFestivalPushToken>?

    @MainActor static let live = Self(
      activities: { FestiCoreFestivalLiveActivity.activities() },
      changes: { FestiCoreFestivalLiveActivity.activityChanges() },
      pushTokenUpdates: { FestiCoreFestivalLiveActivity.pushTokenUpdates(id: $0) }
    )
  }

  private let source: Source
  private let authorization: () async throws -> DeviceAuthorization?
  private let registrationService: any LiveActivityRegistrationService
  private var changesTask: Task<Void, Never>?
  private var tokenTask: Task<Void, Never>?
  private var syncTask: Task<Void, Never>?
  private var selectedActivityID: String?
  private var desiredToken: FestiCoreFestivalPushToken?
  private var registeredToken: FestiCoreFestivalPushToken?
  private var needsRemoval = false
  private var hasRefreshed = false

  init(
    source: Source = .live,
    authorization: @escaping () async throws -> DeviceAuthorization?,
    registrationService: any LiveActivityRegistrationService
  ) {
    self.source = source
    self.authorization = authorization
    self.registrationService = registrationService
  }

  func start() {
    guard changesTask == nil else { return }
    let changes = source.changes()
    changesTask = Task { [weak self] in
      self?.refresh()
      for await _ in changes {
        guard !Task.isCancelled else { return }
        self?.refresh()
      }
    }
  }

  func stop() {
    changesTask?.cancel()
    tokenTask?.cancel()
    syncTask?.cancel()
    changesTask = nil
    tokenTask = nil
    syncTask = nil
  }

  private func refresh() {
    let activities = source.activities().sorted {
      if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
      return $0.id < $1.id
    }
    let selected = activities.first { $0.id == selectedActivityID && $0.state == .active }
      ?? activities.first { $0.state == .active }
      ?? activities.first { $0.id == selectedActivityID }
      ?? activities.first
    if !hasRefreshed {
      hasRefreshed = true
      needsRemoval = selected == nil
    }
    guard selected?.id != selectedActivityID else {
      scheduleSync()
      return
    }

    selectedActivityID = selected?.id
    tokenTask?.cancel()
    tokenTask = nil
    desiredToken = nil
    if selected == nil { needsRemoval = true }
    scheduleSync()

    guard let selected, let updates = source.pushTokenUpdates(selected.id) else { return }
    tokenTask = Task { [weak self] in
      for await token in updates {
        guard !Task.isCancelled else { return }
        self?.receive(token)
      }
    }
  }

  private func receive(_ token: FestiCoreFestivalPushToken) {
    guard token.activityID == selectedActivityID else { return }
    desiredToken = token
    scheduleSync()
  }

  private func scheduleSync() {
    guard syncTask == nil else { return }
    syncTask = Task { [weak self] in
      await self?.synchronize()
      self?.syncTask = nil
    }
  }

  private func synchronize() async {
    var retryDelay = 2
    while !Task.isCancelled {
      let target = desiredToken
      if target == registeredToken && !needsRemoval { return }
      do {
        guard let authorization = try await authorization() else {
          try await Task.sleep(for: .seconds(retryDelay))
          retryDelay = min(retryDelay * 2, 60)
          continue
        }
        if let target {
          try await registrationService.register(
            LiveActivityRegistration(
              festivalID: target.festivalID,
              activityID: target.activityID,
              pushToken: target.value
            ),
            authorization: authorization
          )
          registeredToken = target
        } else {
          try await registrationService.remove(authorization: authorization)
          registeredToken = nil
        }
        needsRemoval = false
        retryDelay = 2
      } catch {
        guard !Task.isCancelled else { return }
        FestiCoreLogger.error("Live Activity 토큰 동기화 실패: \(error.localizedDescription)", category: .app)
        try? await Task.sleep(for: .seconds(retryDelay))
        retryDelay = min(retryDelay * 2, 60)
      }
    }
  }
}
