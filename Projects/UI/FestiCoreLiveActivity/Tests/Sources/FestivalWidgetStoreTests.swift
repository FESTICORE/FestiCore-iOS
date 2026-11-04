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

  private func makeDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
      at: url,
      withIntermediateDirectories: true
    )
    return url
  }
}
