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
    /// 내 줄이면 이름 옆에 "나" 태그를 붙인다.
    let isMe: Bool
    /// 귀가 중이거나 60분 넘게 바뀌지 않은 크루원은 흐리게 그린다.
    let isInactive: Bool
  }

  /// Figma S07 F 모여 요청 배너. 응답 시간(10분) 안에만 그린다.
  struct Gather: Equatable {
    /// "민지: 슬램 존으로 모여!"
    let title: String
    /// "방금 · 크루원 모두에게 소리 알림을 보냈어요"
    let detail: String
    /// 응답 버튼 모양. 보낸 사람이거나 응답할 수 없는 모여면 nil이고 `summary`를 그린다.
    let actions: Actions?
    /// 보낸 사람이 보는 응답 요약. "가는 중 2명 · 확인 1명"
    let summary: String?
  }

  struct Actions: Equatable {
    /// "슬램 존으로 가는 중"
    let goingTitle: String
    /// 내가 고른 응답. 고른 버튼을 진하게 그린다.
    let selected: FestivalCrewGatherResponse?
    let isResponding: Bool
  }

  let summary: String
  /// 카드 머리의 "4 / 12"
  let memberCount: String
  /// 크루가 끝나 기록만 보는 상태(S07 I). 모여!·초대·내 상태를 숨긴다.
  let isArchived: Bool
  let members: [Member]
  let gather: Gather?
  let gatherTitle: String
  let canGather: Bool

  init(
    crew: FestivalCrewFeature.State,
    now: Date
  ) {
    let live = crew.live
    let count = live?.members.count ?? crew.crew?.members.count ?? 0
    let archivedAt = crew.crew?.archivedAt
    isArchived = archivedAt != nil
    memberCount = "\(count) / \(FestivalCrew.maxMembers)"
    if let archivedAt {
      summary = "\(count)명 · \(archivedAt.formatted(.festivalDay))에 끝남"
    } else {
      // Figma S07: `N명 · M/d(E) 자정까지 유지`. 보관 시각(다음 날 00:00) 직전 날짜를 쓴다.
      let until = crew.archivesAt.map {
        " · \($0.addingTimeInterval(-1).formatted(.festivalDay)) 자정까지 유지"
      } ?? ""
      summary = "\(count)명\(until)"
    }
    members = (live?.members ?? []).map { member in
      return Member(
        id: member.id,
        nickname: member.nickname,
        zone: crew.zoneName(member.zoneID),
        status: member.state.flatMap(FestivalLiveBoardPresentation.crewStateText),
        // 끝난 크루는 상대 시간 대신 마지막으로 바뀐 시각을 보여 준다.
        time: archivedAt == nil
          ? FestivalLiveBoardPresentation.relativeTime(
            member.updatedAt,
            now: now
          )
          : member.updatedAt?.formatted(.monthDayTime),
        isMe: member.id == crew.sessionUserID,
        isInactive: member.state == FestivalCrewState.leaving.rawValue
          || member.updatedAt.map { now.timeIntervalSince($0) >= Self.inactiveInterval } ?? false
      )
    }
    gather = live?.gatherRequest.flatMap { request in
      guard archivedAt == nil, request.id == nil || request.id != crew.expiredGatherID,
            now < request.expiresAt ?? request.at.addingTimeInterval(Self.gatherLifetime) else { return nil }
      return Self.gather(
        request,
        crew: crew,
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
  /// 서버가 `expiresAt`을 주지 않던 이전 응답에서 쓰는 모여 응답 시간
  static let gatherLifetime: TimeInterval = 10 * 60

  static func gather(
    _ request: FestivalLiveBoardSnapshot.Crew.GatherRequest,
    crew: FestivalCrewFeature.State,
    now: Date
  ) -> Gather {
    let sender = crew.live?.members.first { $0.id == request.byUserID }?.nickname ?? "크루원"
    let zoneName = crew.zoneName(request.zoneID)
    let place = zoneName.map { "\($0.withEuro) " } ?? ""
    let time = FestivalLiveBoardPresentation.relativeTime(
      request.at,
      now: now
    ).map { "\($0) · " } ?? ""
    let isSender = request.byUserID == crew.sessionUserID
    let canRespond = !isSender && request.id != nil && crew.sessionUserID != nil
    let summary = request.summary
    return Gather(
      title: "\(sender): \(place)모여!",
      detail: "\(time)크루원 모두에게 소리 알림을 보냈어요",
      actions: canRespond
        ? Actions(
          goingTitle: "\(place)가는 중",
          selected: crew.myGatherResponse(request),
          isResponding: crew.isRespondingGather
        )
        : nil,
      summary: isSender
        ? (summary.going + summary.ack == 0
          ? "아직 응답한 크루원이 없어요"
          : "가는 중 \(summary.going)명 · 확인 \(summary.ack)명")
        : nil
    )
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

  /// "…이/가". 숫자로 끝나면 읽는 소리(영·일·삼·육·칠·팔은 받침)로 고른다. 한글·숫자가 아니면 "이"를 쓴다.
  var withIGa: String {
    guard let last = last else { return self }
    if let digit = last.wholeNumberValue, last.isASCII {
      return self + ([2, 4, 5, 9].contains(digit) ? "가" : "이")
    }
    guard let scalar = unicodeScalars.last, (0xAC00 ... 0xD7A3).contains(scalar.value) else {
      return self + "이"
    }
    return self + ((scalar.value - 0xAC00) % 28 == 0 ? "가" : "이")
  }
}
