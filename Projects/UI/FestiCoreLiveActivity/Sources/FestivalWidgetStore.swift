import Dependencies
import FestivalDomainInterface
import Foundation
import OSLog
import WidgetKit

/// 앱과 Widget Extension이 같은 App Group 파일을 통해 축제 화면 데이터를 공유한다.
public enum FestivalWidgetStore {
  private static let groupID = "group.io.festiCore.co"
  private static let fileName = "festival-widget-snapshot.json"
  private static let widgetKind = "FestiCoreFestivalWidget"
  private static let writer = Writer()
  private static let logger = Logger(
    subsystem: "io.festiCore.co",
    category: "FestivalWidgetStore"
  )

  public enum LoadResult: Equatable, Sendable {
    case loaded(FestivalWidgetSnapshot)
    case missing
    case unavailable
  }

  public static func load() -> FestivalWidgetSnapshot? {
    guard case let .loaded(snapshot) = loadResult() else { return nil }
    return snapshot
  }

  public static func loadResult() -> LoadResult {
    return loadResult(at: fileURL())
  }

  static func loadResult(at url: URL?) -> LoadResult {
    guard let url else {
      logger.error("위젯 공유 저장소를 열 수 없습니다.")
      return .unavailable
    }
    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      let failure = error as NSError
      if failure.domain == NSCocoaErrorDomain, failure.code == CocoaError.fileReadNoSuchFile.rawValue {
        return .missing
      }
      logger.error("위젯 데이터를 읽지 못했습니다.")
      return .unavailable
    }
    do {
      return .loaded(try JSONDecoder().decode(
        FestivalWidgetSnapshot.self,
        from: data
      ))
    } catch {
      logger.error("위젯 데이터 형식을 읽지 못했습니다.")
      return .unavailable
    }
  }

  public static func save(_ snapshot: FestivalWidgetSnapshot?) async {
    await writer.save(snapshot)
  }

  private static func fileURL() -> URL? {
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
      .appendingPathComponent(fileName)
  }

  private actor Writer {
    func save(_ snapshot: FestivalWidgetSnapshot?) {
      guard !Task.isCancelled else { return }
      guard let url = FestivalWidgetStore.fileURL() else {
        FestivalWidgetStore.logger.error("위젯 공유 저장소를 열 수 없습니다.")
        return
      }
      if let snapshot {
        do {
          let data = try JSONEncoder().encode(snapshot)
          try data.write(
            to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
          )
        } catch {
          FestivalWidgetStore.logger.error("위젯 데이터 저장에 실패했습니다.")
          return
        }
      } else {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
          try FileManager.default.removeItem(at: url)
        } catch {
          FestivalWidgetStore.logger.error("위젯 데이터 삭제에 실패했습니다.")
          return
        }
      }
      WidgetCenter.shared.reloadTimelines(ofKind: FestivalWidgetStore.widgetKind)
    }
  }
}

extension FestivalWidgetClient: @retroactive DependencyKey {
  public static let liveValue = Self(save: { snapshot in
    await FestivalWidgetStore.save(snapshot)
  })
}
