//
//  FestivalNotificationSettingsUseCaseTests.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestiCoreDeviceInterface
import FestivalDomain
import FestivalDomainInterface
import Foundation
import Testing

struct FestivalNotificationSettingsUseCaseTests {
  @Test func updateSendsOnlyChangedKindsAndMapsServerSettings() async throws {
    let service = StubSettingsService()
    let useCase = withDependencies {
      $0.deviceNotificationSettingsService = service
    } operation: {
      FestivalNotificationSettingsUseCaseImpl()
    }

    let settings = try await useCase.updateSettings([.crewStatus: false, .packUpdates: true])

    #expect(service.changes.value == [DeviceNotificationSettingsChange(crewStatus: false, packUpdates: true)])
    #expect(settings == FestivalNotificationSettings(crewStatus: false, homecoming: false))
    #expect(try await useCase.settings() == FestivalNotificationSettings(crewStatus: false, homecoming: false))
  }

  @Test func serviceErrorsBecomeDomainErrors() async {
    let service = StubSettingsService(error: .deviceNotRegistered)
    let useCase = withDependencies {
      $0.deviceNotificationSettingsService = service
    } operation: {
      FestivalNotificationSettingsUseCaseImpl()
    }

    await #expect(throws: FestivalNotificationSettingsError.deviceNotRegistered) { try await useCase.settings() }
    await #expect(throws: FestivalNotificationSettingsError.deviceNotRegistered) {
      try await useCase.updateSettings([.flagStatus: false])
    }
  }
}

private struct StubSettingsService: DeviceNotificationSettingsService {
  var error: DeviceNotificationSettingsError?
  let changes = LockIsolated<[DeviceNotificationSettingsChange]>([])

  private let server = DeviceNotificationSettings(
    flagStatus: true, crewStatus: false, crewGather: true,
    setReminders: true, homecoming: false, packUpdates: true
  )

  func settings() async throws -> DeviceNotificationSettings {
    if let error { throw error }
    return server
  }

  func update(_ change: DeviceNotificationSettingsChange) async throws -> DeviceNotificationSettings {
    if let error { throw error }
    changes.withValue { $0.append(change) }
    return server
  }
}
