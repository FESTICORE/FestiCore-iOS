//
//  FestivalZoneMapModel.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreDesignKit
import FestivalDomainInterface
import Foundation

/// Figma S06 존 지도에 그릴 존별 마커·존 카드·안내 띠. 상태에서 계산만 한다.
struct FestivalZoneMapModel: Equatable {
  let markers: [String: [Marker]]
  let flagCounts: [String: Int]
  let crewCounts: [String: Int]
  let hasFollowedFlags: Bool
  let hasCrew: Bool
  let flagsEnabled: Bool

  /// 30분 넘게 소식이 없으면 흐리게 그린다(Figma S06 E).
  static let staleInterval: TimeInterval = 30 * 60
  static let crewTints: [FCAvatar.Tint] = [.blue, .pink, .orange, .green, .purple, .yellow]

  enum MarkerKind: Equatable {
    case followedFlag
    case otherFlag
    case crew(CrewBadge)
  }

  /// 크루원 원 안의 첫 글자와 색
  struct CrewBadge: Equatable {
    let initial: String
    let tint: FCAvatar.Tint
  }

  struct Marker: Equatable, Identifiable {
    let id: String
    let name: String
    let kind: MarkerKind
    let isStale: Bool
  }

  /// 존 카드(Figma S06 B~E)
  struct Card: Equatable {
    let zoneID: String
    let name: String
    let meta: String
    let flags: [FlagRow]
    let crew: [CrewRow]

    var isEmpty: Bool {
      return flags.isEmpty && crew.isEmpty
    }

    var hasStaleCrew: Bool {
      return crew.contains(where: \.isStale)
    }
  }

  struct FlagRow: Equatable, Identifiable {
    let id: String
    let name: String
    let meta: String
    let time: String
    let status: FCStatusChip.Status
  }

  struct CrewRow: Equatable, Identifiable {
    let id: String
    let nickname: String
    let zone: String
    let status: String
    let time: String
    let isMe: Bool
    let tint: FCAvatar.Tint
    let isStale: Bool
  }

  /// 아래 안내 띠. 존 카드가 없을 때만 보인다.
  enum BottomBanner: Equatable {
    /// Figma S06 F
    case followGuide
    /// Figma S06 H
    case flagsDisabled
  }
}

extension FestivalZoneMapModel {
  init(
    map: FestivalZoneMap,
    snapshot: FestivalLiveBoardSnapshot?,
    viewerUserID: String?,
    now: Date
  ) {
    let zoneIDs = Set(map.zones.map(\.id))
    let followedIDs = Set(snapshot?.followedFlags.map(\.id) ?? [])
    let flags = map.flagsEnabled ? Self.placedFlags(
      snapshot,
      zoneIDs: zoneIDs
    ) : []
    let members = (snapshot?.crew?.members ?? []).enumerated().filter { entry in
      return entry.element.zoneID.map(zoneIDs.contains) == true
    }
    var markers: [String: [Marker]] = [:]
    var flagCounts: [String: Int] = [:]
    var crewCounts: [String: Int] = [:]
    // 시안 순서: 팔로우 깃발 → 크루 → 다른 깃발
    for flag in flags where followedIDs.contains(flag.id) {
      markers[flag.zoneID ?? "", default: []].append(Marker(
        id: flag.id,
        name: flag.name,
        kind: .followedFlag,
        isStale: Self.isStale(
          flag.updatedAt,
          now: now
        )
      ))
    }
    for entry in members {
      let member = entry.element
      let index = entry.offset
      markers[member.zoneID ?? "", default: []].append(Marker(
        id: member.id,
        name: member.nickname,
        kind: .crew(CrewBadge(
          initial: String(member.nickname.prefix(1)),
          tint: Self.crewTints[index % Self.crewTints.count]
        )),
        isStale: Self.isStale(
          member.updatedAt,
          now: now
        )
      ))
      crewCounts[member.zoneID ?? "", default: 0] += 1
    }
    for flag in flags {
      flagCounts[flag.zoneID ?? "", default: 0] += 1
      guard !followedIDs.contains(flag.id) else { continue }
      markers[flag.zoneID ?? "", default: []].append(Marker(
        id: flag.id,
        name: flag.name,
        kind: .otherFlag,
        isStale: Self.isStale(
          flag.updatedAt,
          now: now
        )
      ))
    }
    self.markers = markers
    self.flagCounts = flagCounts
    self.crewCounts = crewCounts
    hasFollowedFlags = flags.contains { followedIDs.contains($0.id) }
    hasCrew = !members.isEmpty
    flagsEnabled = map.flagsEnabled
  }

  var bottomBanner: BottomBanner? {
    if !flagsEnabled { return .flagsDisabled }
    if !hasFollowedFlags && !hasCrew { return .followGuide }
    return nil
  }

  /// 존 목록(Figma S06 I)의 오른쪽 값. 없으면 `–`
  func countText(_ zoneID: String) -> String {
    let parts = [
      flagCounts[zoneID].map { "깃발 \($0)" },
      crewCounts[zoneID].map { "크루 \($0)" },
    ].compactMap { $0 }
    return parts.isEmpty ? "–" : parts.joined(separator: " · ")
  }

  static func card(
    zone: FestivalZoneMap.Zone,
    map: FestivalZoneMap,
    snapshot: FestivalLiveBoardSnapshot?,
    viewerUserID: String?,
    now: Date
  ) -> Card {
    let followedIDs = Set(snapshot?.followedFlags.map(\.id) ?? [])
    let flags = map.flagsEnabled ? placedFlags(
      snapshot,
      zoneIDs: [zone.id]
    ) : []
    let ordered = flags.filter { followedIDs.contains($0.id) } + flags.filter { !followedIDs.contains($0.id) }
    let flagRows = ordered.map { flag in
      let activity = flag.activity.flatMap(FestivalLiveBoardPresentation.tagText)
      let followed = followedIDs.contains(flag.id) ? "팔로우 중" : nil
      return FlagRow(
        id: flag.id,
        name: flag.name,
        meta: [followed, activity].compactMap { $0 }.joined(separator: " · "),
        time: FestivalLiveBoardPresentation.relativeTime(
          flag.updatedAt,
          now: now
        ) ?? "",
        status: flag.status == "resting" ? .resting : .active
      )
    }
    let crewRows = (snapshot?.crew?.members ?? []).enumerated().compactMap { index, member -> CrewRow? in
      guard member.zoneID == zone.id else { return nil }
      return CrewRow(
        id: member.id,
        nickname: member.nickname,
        zone: zone.name,
        status: member.state.flatMap(FestivalLiveBoardPresentation.crewStateText) ?? "",
        time: FestivalLiveBoardPresentation.relativeTime(
          member.updatedAt,
          now: now
        ) ?? "",
        isMe: viewerUserID != nil && member.id == viewerUserID,
        tint: crewTints[index % crewTints.count],
        isStale: isStale(
          member.updatedAt,
          now: now
        )
      )
    }
    let counts = [
      flagRows.isEmpty ? nil : "깃발 \(flagRows.count)",
      crewRows.isEmpty ? nil : "크루 \(crewRows.count)",
    ].compactMap { $0 }
    let presence = counts.isEmpty ? ["지금 아무도 없어요"] : counts
    return Card(
      zoneID: zone.id,
      name: zone.name,
      meta: ([zone.kind].compactMap { $0 } + presence).joined(separator: " · "),
      flags: flagRows,
      crew: crewRows
    )
  }
}

private extension FestivalZoneMapModel {
  static func placedFlags(
    _ snapshot: FestivalLiveBoardSnapshot?,
    zoneIDs: Set<String>
  ) -> [FestivalLiveBoardSnapshot.Flag] {
    return (snapshot?.activeFlags ?? []).filter { flag in
      return ["active", "resting"].contains(flag.status) && flag.zoneID.map(zoneIDs.contains) == true
    }
  }

  static func isStale(
    _ date: Date?,
    now: Date
  ) -> Bool {
    guard let date else { return false }
    return now.timeIntervalSince(date) > staleInterval
  }
}
