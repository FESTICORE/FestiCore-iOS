import FestivalDomainInterface
import Foundation
import Testing
@testable import FestiCoreLiveActivity

struct FestivalWidgetStoreTests {
  @Test func unavailableContainerIsNotMissingSnapshot() {
    #expect(FestivalWidgetStore.loadResult(at: nil) == .unavailable)
  }

  @Test func absentSnapshotIsMissing() {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    #expect(FestivalWidgetStore.loadResult(at: url) == .missing)
  }

  @Test func unreadableSnapshotIsNotMissing() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    #expect(FestivalWidgetStore.loadResult(at: directory) == .unavailable)
  }

  @Test func invalidJSONIsNotMissing() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("snapshot.json")
    try Data("{invalid".utf8).write(to: url)

    #expect(FestivalWidgetStore.loadResult(at: url) == .unavailable)
  }

  @Test func invalidSnapshotSchemaIsNotMissing() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("snapshot.json")
    try Data("{}".utf8).write(to: url)

    #expect(FestivalWidgetStore.loadResult(at: url) == .unavailable)
  }

  @Test func validSnapshotLoadsWithoutChangingPayload() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("snapshot.json")
    let snapshot = FestivalWidgetSnapshot(
      festivalID: "festival",
      festivalName: "축제",
      firstDay: nil,
      lastDay: nil,
      updatedAt: Date(timeIntervalSince1970: 100),
      hasPack: true,
      performances: []
    )
    try JSONEncoder().encode(snapshot).write(to: url)

    #expect(FestivalWidgetStore.loadResult(at: url) == .loaded(snapshot))
  }

  /// 셔틀·막차 칸이 없던 이전 버전 스냅샷도 읽고, 새 칸은 저장한 그대로 다시 읽는다.
  @Test func shuttleAndTrainFieldsStayBackwardCompatible() throws {
    let directory = try makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("snapshot.json")
    try Data(#"{"festivalID":"festival","festivalName":"축제","updatedAt":100,"hasPack":true,"performances":[]}"#.utf8)
      .write(to: url)

    guard case let .loaded(legacy) = FestivalWidgetStore.loadResult(at: url) else {
      Issue.record("이전 버전 스냅샷을 읽지 못했다")
      return
    }
    #expect(legacy.lastShuttleAt == nil)
    #expect(legacy.shuttleStopName == nil)
    #expect(legacy.lastTrainAt == nil)
    #expect(legacy.trainStationName == nil)

    let snapshot = FestivalWidgetSnapshot(
      festivalID: "festival",
      festivalName: "축제",
      firstDay: nil,
      lastDay: nil,
      updatedAt: Date(timeIntervalSince1970: 100),
      hasPack: true,
      performances: [],
      lastShuttleAt: Date(timeIntervalSince1970: 200),
      shuttleStopName: "정문",
      lastTrainAt: Date(timeIntervalSince1970: 300),
      trainStationName: "킨텍스역"
    )
    try JSONEncoder().encode(snapshot).write(to: url)

    #expect(FestivalWidgetStore.loadResult(at: url) == .loaded(snapshot))
    #expect(snapshot.withUpdatedAt(Date(timeIntervalSince1970: 400)).trainStationName == "킨텍스역")
  }

  private func makeDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: true
    )
    return url
  }
}
