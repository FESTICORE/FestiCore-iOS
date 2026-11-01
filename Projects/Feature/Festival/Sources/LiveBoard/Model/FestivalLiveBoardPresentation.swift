//
//  FestivalLiveBoardPresentation.swift
//  Festival
//
//  Created by FestiCore on 10/31/26.
//

import FestiCoreUtility
import FestivalDomainInterface
import Foundation

/// 라이브 보드 화면에 그릴 값을 계산한다. `now`는 `serverNow`로 보정한 시각을 받는다.
enum FestivalLiveBoardPresentation {
  enum FlagStatus: Equatable {
    case active
    case resting
    case ended
  }

  struct StageRow: Equatable, Identifiable {
    struct Slot: Equatable {
      let artist: String
      let time: String
    }

    let id: String
    let name: String
    let now: Slot?
    let next: Slot?
    let isMine: Bool
  }

  struct SetCard: Equatable {
    let label: String
    let artist: String
    let meta: String
    let remain: String
    let progress: Double
  }

  struct Countdown: Equatable {
    let time: String
    let sub: String
  }

  struct CrewMember: Equatable, Identifiable {
    let id: String
    let nickname: String
    let isMe: Bool
    let zone: String?
    let status: String?
    let time: String?
    let isLeaving: Bool
  }

  struct Crew: Equatable {
    let title: String
    let subtitle: String
    let members: [CrewMember]
  }

  struct Flag: Equatable, Identifiable {
    let id: String
    let name: String
    let status: FlagStatus?
    let zone: String?
    let tags: String
    let meta: String
    let time: String?
    let thumbnailURL: URL?
  }
}

// MARK: - 시각

extension FestivalLiveBoardPresentation {
  static func sortedActiveFlags(
    _ flags: [FestivalLiveBoardSnapshot.Flag]
  ) -> [FestivalLiveBoardSnapshot.Flag] {
    flags.sorted {
      let left = $0.updatedAt ?? .distantPast
      let right = $1.updatedAt ?? .distantPast
      return left == right ? $0.id < $1.id : left > right
    }
  }

  /// 서버 시각에 첫 수신 후 흐른 기기 시간을 더한다. 304 확인은 기준점을 바꾸지 않는다.
  static func serverNow(serverAt: Date?, clockAnchorAt: Date?, deviceNow: Date) -> Date {
    guard let serverAt, let clockAnchorAt else { return deviceNow }
    return serverAt.addingTimeInterval(deviceNow.timeIntervalSince(clockAnchorAt))
  }

  static func relativeTime(_ date: Date?, now: Date) -> String? {
    guard let date else { return nil }
    let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
    if minutes < 1 { return "방금" }
    if minutes < 60 { return "\(minutes)분 전" }
    let hours = minutes / 60
    return hours < 24 ? "\(hours)시간 전" : "\(hours / 24)일 전"
  }

  /// 다음 일정 카드의 갱신 문구. 수신 시각과 같은 기기 시각으로 잰다.
  static func updatedText(receivedAt: Date?, deviceNow: Date) -> String {
    relativeTime(receivedAt, now: deviceNow).map { "\($0) 업데이트" } ?? "시간표 기준"
  }

  /// 오프라인 배너 문구. 경과 시간은 기기 시각으로 잰다.
  static func offlineText(receivedAt: Date?, deviceNow: Date) -> String {
    guard let age = relativeTime(receivedAt, now: deviceNow) else { return "오프라인" }
    return "오프라인 · \(age) 정보"
  }
}

// MARK: - 축제·일정

extension FestivalLiveBoardPresentation {
  /// `DAY n · M/d(E) · HH:mm–HH:mm`. 오늘 날짜가 없으면 첫날을 쓴다.
  static func dayLine(pack: FestivalPackDocument?, festival: FestivalOverview, now: Date) -> String? {
    guard let day = selectedDay(pack: pack, festival: festival, now: now) else { return nil }
    var parts = ["DAY \(day.index + 1)"]
    if let date = day.date.date(as: .day) { parts.append(date.formatted(.liveBoardDay)) }
    if let start = day.startsAt, let end = day.endsAt {
      parts.append("\(start.formatted(.time))–\(end.formatted(.time))")
    }
    return parts.joined(separator: " · ")
  }

  /// 오늘 개장 전이면 카운트다운을 돌려준다.
  static func countdown(pack: FestivalPackDocument?, festival: FestivalOverview, now: Date) -> Countdown? {
    guard let day = selectedDay(pack: pack, festival: festival, now: now),
          let opensAt = day.startsAt, now < opensAt else { return nil }
    var sub = "\(opensAt.formatted(.time)) 개장"
    if let pack, let first = FestivalLiveBoardSchedule.entries(pack: pack).first(where: { $0.slot.startsAt >= opensAt }) {
      sub += " · 첫 공연 \(first.slot.startsAt.formatted(.time)) \(first.stageName)"
    }
    return Countdown(time: duration(from: now, to: opensAt), sub: sub)
  }

  /// 내 다음 일정, 없으면 전체 다음 공연. 개장 전에는 첫 공연 시작 시각을 보인다.
  static func setCard(pack: FestivalPackDocument?, mySetIDs: Set<String>, isBeforeOpening: Bool, now: Date) -> SetCard? {
    guard let pack else { return nil }
    let entries = FestivalLiveBoardSchedule.entries(pack: pack)
    let mine = entries.first { mySetIDs.contains($0.slot.id) && (($0.slot.endsAt ?? $0.slot.startsAt) > now) }
    let entry: FestivalLiveBoardSchedule.Entry?
    let label: String
    if let mine {
      entry = mine
      label = isBeforeOpening ? "내 첫 공연" : "내 다음 일정"
    } else {
      entry = entries.first { $0.slot.startsAt > now }
      label = isBeforeOpening ? "첫 공연" : "다음 공연"
    }
    guard let entry else { return nil }
    let slot = entry.slot
    let range = slot.endsAt.map { "\(slot.startsAt.formatted(.time))–\($0.formatted(.time))" } ?? slot.startsAt.formatted(.time)
    let meta = "\(entry.stageName) · \(range)"
    if isBeforeOpening {
      return SetCard(label: label, artist: slot.artist, meta: meta, remain: slot.startsAt.formatted(.time), progress: 0)
    }
    if slot.startsAt <= now, let end = slot.endsAt {
      let elapsed = now.timeIntervalSince(slot.startsAt) / end.timeIntervalSince(slot.startsAt)
      return SetCard(label: label, artist: slot.artist, meta: meta, remain: "공연 중", progress: min(max(elapsed, 0), 1))
    }
    let minutes = slot.startsAt.timeIntervalSince(now) / 60
    return SetCard(
      label: label, artist: slot.artist, meta: meta,
      remain: remaining(minutes: Int(minutes)),
      progress: min(max(1 - minutes / 60, 0), 1)
    )
  }

  static func stageRows(_ stages: [FestivalLiveBoardSchedule.Stage], mySetIDs: Set<String>) -> [StageRow] {
    stages.map { stage in
      StageRow(
        id: stage.id,
        name: stage.name,
        now: stage.current.map { .init(artist: $0.artist, time: $0.endsAt.map { "\($0.formatted(.time)) 종료" } ?? "공연 중") },
        next: stage.next.map { .init(artist: $0.artist, time: "\($0.startsAt.formatted(.time)) 시작") },
        isMine: [stage.current?.id, stage.next?.id].contains { $0.map(mySetIDs.contains) ?? false }
      )
    }
  }

  /// `출처: 이름 · 확인 MM/dd HH:mm`. 이름이 없으면 줄을 그리지 않는다.
  static func sourceLine(_ source: FestivalPackDocument.Source?) -> String? {
    guard let name = source?.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
    guard let verifiedAt = source?.verifiedAt.flatMap(FestivalLiveBoardSchedule.parse) else { return "출처: \(name)" }
    return "출처: \(name) · 확인 \(verifiedAt.formatted(.monthDayTime))"
  }
}

// MARK: - 크루·깃발

extension FestivalLiveBoardPresentation {
  static func crew(
    _ crew: FestivalLiveBoardSnapshot.Crew,
    sessionUserID: String?,
    zoneName: (String?) -> String?,
    now: Date
  ) -> Crew {
    let members = crew.members.map { member in
      CrewMember(
        id: member.id,
        nickname: member.nickname,
        isMe: sessionUserID != nil && member.id == sessionUserID,
        zone: zoneName(member.zoneID),
        status: member.state.flatMap(crewStateText),
        time: relativeTime(member.updatedAt, now: now),
        isLeaving: member.state == "leaving"
      )
    }
    var counts: [String: Int] = [:]
    for zone in members.compactMap(\.zone) { counts[zone, default: 0] += 1 }
    let busiest = counts.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }
    let subtitle = busiest.map { "\(members.count)명 · \($0.value)명이 \($0.key) 근처" } ?? "\(members.count)명"
    return Crew(title: "내 크루 · \(crew.name)", subtitle: subtitle, members: members)
  }

  static func flag(_ flag: FestivalLiveBoardSnapshot.Flag, zoneName: (String?) -> String?, now: Date) -> Flag {
    let zone = zoneName(flag.zoneID)
    return Flag(
      id: flag.id,
      name: flag.name,
      status: flagStatus(flag.status),
      zone: zone,
      tags: flag.tags.compactMap(tagText).joined(separator: " · "),
      meta: [zone, flag.activity.flatMap(tagText)].compactMap { $0 }.joined(separator: " · "),
      time: relativeTime(flag.updatedAt, now: now),
      thumbnailURL: flag.thumbnailURL
    )
  }

  static func flagStatus(_ value: String) -> FlagStatus? {
    switch value {
    case "active": .active
    case "resting": .resting
    case "ended": .ended
    default: nil
    }
  }

  static func crewStateText(_ value: String) -> String? {
    switch value {
    case "here": "나 여기"
    case "eating": "밥"
    case "toilet": "화장실"
    case "leaving": "귀가 중"
    default: nil
    }
  }

  /// 깃발 성향 태그와 활동 문구. `resting` 같은 값은 표시하지 않는다.
  static func tagText(_ value: String) -> String? {
    switch value {
    case "slam": "슬램"
    case "sing": "떼창"
    case "train": "기차놀이"
    case "calm": "차분"
    case "newbie": "초보 환영"
    default: nil
    }
  }
}

private extension FestivalLiveBoardPresentation {
  struct Day {
    let index: Int
    let date: String
    let startsAt: Date?
    let endsAt: Date?
  }


  static func selectedDay(pack: FestivalPackDocument?, festival: FestivalOverview, now: Date) -> Day? {
    let packDays = (pack?.days ?? []).filter { $0.date?.date(as: .day) != nil }
    let dates: [String] = packDays.isEmpty
      ? [festival.firstDate, festival.lastDate].compactMap { $0 }.filter { $0.date(as: .day) != nil }
      : packDays.compactMap(\.date)
    let sorted = Array(Set(dates)).sorted()
    let today = AppDateFormat.calendar.startOfDay(for: now)
    guard let date = sorted.first(where: { $0.date(as: .day) == today }) ?? sorted.first,
          let index = sorted.firstIndex(of: date) else { return nil }
    let packDay = packDays.first { $0.date == date }
    return Day(
      index: index,
      date: date,
      startsAt: packDay?.startsAt.flatMap(FestivalLiveBoardSchedule.parse),
      endsAt: packDay?.endsAt.flatMap(FestivalLiveBoardSchedule.parse)
    )
  }

  static func duration(from now: Date, to date: Date) -> String {
    let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
    let hours = minutes / 60
    if hours >= 24 { return "\(hours / 24)일 \(hours % 24)시간" }
    return hours > 0 ? "\(hours)시간 \(minutes % 60)분" : "\(minutes)분"
  }

  static func remaining(minutes: Int) -> String {
    let minutes = max(0, minutes)
    if minutes < 60 { return "\(minutes)분 후" }
    let hours = minutes / 60
    return hours < 24 ? "\(hours)시간 후" : "\(hours / 24)일 후"
  }
}
