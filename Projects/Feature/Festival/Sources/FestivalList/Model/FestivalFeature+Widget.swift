import FestivalDomainInterface
import FestiCoreUtility
import Foundation

struct FestivalWidgetContent: Equatable, Sendable {
  let festivalID: String
  let festivalName: String
  let firstDay: Date?
  let lastDay: Date?
  let hasPack: Bool
  let performances: [FestivalWidgetSnapshot.Performance]
  let crewName: String?

  func snapshot(updatedAt: Date) -> FestivalWidgetSnapshot {
    return FestivalWidgetSnapshot(
      festivalID: festivalID,
      festivalName: festivalName,
      firstDay: firstDay,
      lastDay: lastDay,
      updatedAt: updatedAt,
      hasPack: hasPack,
      performances: performances,
      crewName: crewName
    )
  }
}

extension FestivalFeature.State {
  /// 상위 코디네이터가 활성 축제 화면 하나를 골라 공유 저장소에 기록할 값.
  /// 비교 중 시각이 달라지지 않도록 실제 저장 시각은 상위에서 넣는다.
  public var widgetSnapshotContent: FestivalWidgetSnapshot? {
    return widgetContent?.snapshot(updatedAt: .distantPast)
  }

  var widgetContent: FestivalWidgetContent? {
    guard let festival = selectedFestival else { return nil }
    let document = displayDocument
    let dayDates = document?.days?.compactMap { $0.date?.date(as: .day) } ?? []
    let stageNames = (document?.stages ?? []).reduce(into: [String: String]()) { names, stage in
      if names[stage.id] == nil { names[stage.id] = stage.name }
    }
    let savedIDs = hasSession && mySchedule?.festivalID == festival.id
      ? mySchedule?.setIDs ?? [] : []
    let performances = (document?.performances ?? []).compactMap { performance -> FestivalWidgetSnapshot.Performance? in
      guard let artist = performance.artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty,
            let startsAt = performance.startsAt.flatMap(FestivalLiveBoardSchedule.parse),
            let endsAt = performance.endsAt.flatMap(FestivalLiveBoardSchedule.parse),
            endsAt > startsAt else { return nil }
      let stageName = [performance.stageName, performance.stageId.flatMap { stageNames[$0] }]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? "무대 정보 없음"
      return FestivalWidgetSnapshot.Performance(
        id: performance.id,
        artist: artist,
        stageName: stageName,
        startsAt: startsAt,
        endsAt: endsAt,
        isSaved: savedIDs.contains(performance.id)
      )
    }
    .sorted { $0.startsAt == $1.startsAt ? $0.id < $1.id : $0.startsAt < $1.startsAt }
    return FestivalWidgetContent(
      festivalID: festival.id,
      festivalName: festival.name,
      firstDay: festival.firstDate?.date(as: .day) ?? dayDates.min(),
      lastDay: festival.lastDate?.date(as: .day) ?? dayDates.max(),
      hasPack: selectedPack?.id == festival.id && cachedPacks[festival.id] != nil,
      performances: performances,
      crewName: hasSession && liveBoard?.festivalID == festival.id ? liveBoard?.crew?.name : nil
    )
  }
}
