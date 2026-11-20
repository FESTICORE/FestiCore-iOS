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
    // 이 서버 응답에는 officialNews가 없어 화면에서 숨긴다.
    let expected = FestivalNotificationSettings(
      crewStatus: false,
      homecoming: false,
      isOfficialNewsAvailable: false
    )
    #expect(settings == expected)
    #expect(try await useCase.settings() == expected)
  }

  @Test func officialNewsIsShownOnlyWhenServerReturnsIt() async throws {
    let service = StubSettingsService(officialNews: false)
    let useCase = withDependencies {
      $0.deviceNotificationSettingsService = service
    } operation: {
      FestivalNotificationSettingsUseCaseImpl()
    }

    let settings = try await useCase.updateSettings([.officialNews: false])

    #expect(service.changes.value == [DeviceNotificationSettingsChange(officialNews: false)])
    #expect(settings.officialNews == false)
    #expect(settings.isOfficialNewsAvailable)
    #expect(settings[.officialNews] == false)
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
  var officialNews: Bool?
  let changes = LockIsolated<[DeviceNotificationSettingsChange]>([])

  private var server: DeviceNotificationSettings {
    return DeviceNotificationSettings(
      flagStatus: true,
      crewStatus: false,
      crewGather: true,
      setReminders: true,
      homecoming: false,
      packUpdates: true,
      officialNews: officialNews
    )
  }

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
