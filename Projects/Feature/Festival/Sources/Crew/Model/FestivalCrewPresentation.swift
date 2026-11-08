import FestiCoreUtility
import FestivalDomainInterface
import Foundation

/// Figma S07 크루 화면에 그리는 값. 서버 값과 지금 시각으로 문구를 만든다.
struct FestivalCrewPresentation: Equatable {
  struct Member: Equatable, Identifiable {
    let id: String
    let nickname: String
    let zone: String?
    let status: String?
    let time: String?
    /// 귀가 중이거나 60분 넘게 바뀌지 않은 크루원은 흐리게 그린다.
    let isInactive: Bool
  }

  let summary: String
  let members: [Member]
  let gatherNotice: String?
  let gatherTitle: String
  let canGather: Bool

  init(
    crew: FestivalCrewFeature.State,
    now: Date
  ) {
    let live = crew.live
    let count = live?.members.count ?? crew.crew?.members.count ?? 0
    let until = crew.archivesAt.map {
      " · \($0.formatted(.festivalDay)) \($0.formatted(.time))까지"
    } ?? ""
    summary = "\(count)명\(until)"
    members = (live?.members ?? []).map { member in
      return Member(
        id: member.id,
        nickname: member.nickname,
        zone: crew.zoneName(member.zoneID),
        status: member.state.flatMap(FestivalLiveBoardPresentation.crewStateText),
        time: FestivalLiveBoardPresentation.relativeTime(
          member.updatedAt,
          now: now
        ),
        isInactive: member.state == FestivalCrewState.leaving.rawValue
          || member.updatedAt.map { now.timeIntervalSince($0) >= Self.inactiveInterval } ?? false
      )
    }
    gatherNotice = live?.gatherRequest.flatMap { request in
      return Self.gatherNotice(
        request,
        members: live?.members ?? [],
        zoneName: crew.zoneName(request.zoneID),
        now: now
      )
    }
    let remaining = live?.gatherAvailableAt.map { $0.timeIntervalSince(now) } ?? 0
    if remaining > 0 {
      let minutes = Int((remaining / 60).rounded(.up))
      gatherTitle = "모여! · \(minutes)분 뒤 다시 가능"
      canGather = false
    } else {
      gatherTitle = "모여!"
      canGather = crew.crew?.archivedAt == nil
    }
  }
}

private extension FestivalCrewPresentation {
  static let inactiveInterval: TimeInterval = 60 * 60

  static func gatherNotice(
    _ request: FestivalLiveBoardSnapshot.Crew.GatherRequest,
    members: [FestivalLiveBoardSnapshot.Crew.Member],
    zoneName: String?,
    now: Date
  ) -> String? {
    guard let sender = members.first(where: { $0.id == request.byUserID })?.nickname else { return nil }
    let place = zoneName.map { "\($0.withEuro) 모여" } ?? "모여"
    let time = FestivalLiveBoardPresentation.relativeTime(
      request.at,
      now: now
    ).map { " · \($0)" } ?? ""
    return "\(sender)님이 \"\(place)\"를 보냈어요\(time)"
  }
}

extension String {
  /// "…으로/로". 받침 ㄹ 뒤와 받침 없는 글자 뒤에는 "로"를 쓴다.
  var withEuro: String {
    guard let scalar = unicodeScalars.last, (0xAC00 ... 0xD7A3).contains(scalar.value) else {
      return self + "로"
    }
    let jongseong = (scalar.value - 0xAC00) % 28
    return self + (jongseong == 0 || jongseong == 8 ? "로" : "으로")
  }
}
