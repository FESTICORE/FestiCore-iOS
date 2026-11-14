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
  let days: [FestivalWidgetSnapshot.Day]
  let pinnedFlagSummary: String?
  let crewLocationSummary: String?

  func snapshot(updatedAt: Date) -> FestivalWidgetSnapshot {
    return FestivalWidgetSnapshot(
      festivalID: festivalID,
      festivalName: festivalName,
      firstDay: firstDay,
      lastDay: lastDay,
      updatedAt: updatedAt,
      hasPack: hasPack,
      performances: performances,
      crewName: crewName,
      days: days,
      pinnedFlagSummary: pinnedFlagSummary,
      crewLocationSummary: crewLocationSummary
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
    let board = hasSession && liveBoard?.festivalID == festival.id ? liveBoard : nil
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
      crewName: hasSession && liveBoard?.festivalID == festival.id ? liveBoard?.crew?.name : nil,
      days: Self.widgetDays(document?.days ?? []),
      pinnedFlagSummary: board.flatMap { Self.widgetPinnedFlagSummary(
        $0,
        document: document
      ) },
      crewLocationSummary: board?.crew.flatMap { Self.widgetCrewLocationSummary(
        $0,
        document: document
      ) }
    )
  }

  /// Figma Widget Medium Info(flag): `{깃발} · {존} · {활동}`. 존과 활동이 모두 없으면 보이지 않는다.
  static func widgetPinnedFlagSummary(
    _ board: FestivalLiveBoardSnapshot,
    document: FestivalPackDocument?
  ) -> String? {
    guard let pinnedID = board.pinnedFlagID,
          let flag = board.followedFlags.first(where: { $0.id == pinnedID }) else { return nil }
    let details = [
      document?.zoneName(for: flag.zoneID),
      flag.activity.flatMap(FestivalLiveBoardPresentation.tagText),
    ].compactMap { $0 }
    guard !details.isEmpty else { return nil }
    return ([flag.name] + details).joined(separator: " · ")
  }

  /// Figma Widget 크루 위치: `크루 3명 슬램존 · 1명 밥`. 밥·화장실·귀가 중은 상태로, 그 밖은 존 이름으로 묶어 많은 순 두 곳을 보인다.
  static func widgetCrewLocationSummary(
    _ crew: FestivalLiveBoardSnapshot.Crew,
    document: FestivalPackDocument?
  ) -> String? {
    var counts: [String: Int] = [:]
    var order: [String] = []
    for member in crew.members {
      let away = member.state.flatMap { $0 == "here" ? nil : FestivalLiveBoardPresentation.crewStateText($0) }
      guard let place = away ?? document?.zoneName(for: member.zoneID) else { continue }
      if counts[place] == nil { order.append(place) }
      counts[place, default: 0] += 1
    }
    let places = order.enumerated().sorted { left, right in
      let leftCount = counts[left.element] ?? 0
      let rightCount = counts[right.element] ?? 0
      return leftCount == rightCount ? left.offset < right.offset : leftCount > rightCount
    }
    .prefix(2)
    .map { "\(counts[$0.element] ?? 0)명 \($0.element)" }
    guard !places.isEmpty else { return nil }
    return "크루 " + places.joined(separator: " · ")
  }

  /// 팩 일자를 날짜순 위젯 일자로 바꾼다. 날짜가 없는 일자는 뺀다.
  static func widgetDays(_ days: [FestivalPackDocument.Day]) -> [FestivalWidgetSnapshot.Day] {
    return days.compactMap { day -> FestivalWidgetSnapshot.Day? in
      guard let date = day.date?.date(as: .day) else { return nil }
      return FestivalWidgetSnapshot.Day(
        date: date,
        opensAt: day.startsAt.flatMap(FestivalLiveBoardSchedule.parse)
      )
    }
    .sorted { $0.date < $1.date }
  }
}
