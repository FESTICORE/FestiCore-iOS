import FestivalDomainInterface
import Foundation

/// 라이브 보드 화면에 필요한 상태만 모은 표시 모델.
struct FestivalLiveBoardScreenModel {
  struct HomeRide {
    let remain: String
    let shuttle: String
    let train: String
  }

  struct DoneSummary {
    let seenSetCount: Int
    let crewCount: Int
    let followedFlagCount: Int
  }

  let pack: FestivalPackDocument?
  let liveBoard: FestivalLiveBoardSnapshot?
  let connection: FestivalFeature.Connection
  let liveBoardUnavailable: Bool
  let liveBoardUnpublished: Bool
  let isPackLoading: Bool
  let liveBoardClockAnchorAt: Date?
  let liveBoardReceivedAt: Date?
  let hasSession: Bool
  let hasUnreadNotifications: Bool
  let sessionUserID: String?
  let mySetIDs: Set<String>
  let hasMySchedule: Bool
  let myScheduleUnavailable: Bool
  let homeDetails: FestivalFeature.HomeDetailsState
  /// Apple 지도로 계산한 도보 분. 계산하지 못한 역은 서버 값이다.
  let homeWalkMinutes: FestivalFeature.HomeWalkMinutes
  let showsFollowGuide: Bool
  /// 선택 축제의 팩을 받는 중이면 진행 표시
  let packDownload: FestivalPackDownloadDisplay?

  init(state: FestivalFeature.State) {
    connection = state.connection
    pack = state.displayDocument
    liveBoard = state.liveBoard
    liveBoardUnavailable = state.liveBoardUnavailable
    liveBoardUnpublished = state.liveBoardUnpublished
    isPackLoading = state.isPackLoading
    liveBoardClockAnchorAt = state.liveBoardClockAnchorAt
    liveBoardReceivedAt = state.liveBoardReceivedAt
    hasSession = state.hasSession
    hasUnreadNotifications = state.hasUnreadNotifications
    sessionUserID = state.sessionUserID
    mySetIDs = state.mySchedule?.setIDs ?? []
    hasMySchedule = state.mySchedule != nil
    myScheduleUnavailable = state.myScheduleUnavailable
    homeDetails = state.homeDetails
    homeWalkMinutes = state.homeWalkMinutes
    showsFollowGuide = state.showsFollowGuide
    packDownload = state.packDownloadDisplay(for: state.selectedFestivalID)
  }

  var showsOfflineStatus: Bool {
    return (liveBoardUnavailable && !liveBoardUnpublished) || connection == .offline || connection == .reconnecting
  }

  func homeRide(now: Date) -> HomeRide? {
    guard let festivalID = pack?.id,
          let directions = homeDetails.directions(for: festivalID),
          let departure = FestivalHomeDeparture(
            directions: directions,
            walkMinutes: homeWalkMinutes,
            now: now
          ) else { return nil }
    let shuttleAt = nonempty(directions.lastShuttleAt)
    let trainAt = nonempty(directions.lastTrainAt)
    let shuttleStation = directions.shuttleStopName.map { " · \($0)" } ?? ""
    let trainStation = directions.transit?.stationName.map { " · \($0)" } ?? ""
    let shuttleWalk = walkText(homeWalkMinutes.shuttleStop)
    let trainWalk = walkText(homeWalkMinutes.station)
    return HomeRide(
      remain: "\(departure.name)까지 \(departure.remainingMinutes(now: now))분",
      shuttle: shuttleAt.map { "마지막 셔틀 \(timeText($0))\(shuttleStation)\(shuttleWalk)" } ?? "셔틀 시간 미공개",
      train: trainAt.map { "막차 \(timeText($0))\(trainStation)\(trainWalk)" } ?? "막차 시간 미공개"
    )
  }

  var isHomeRideLoading: Bool {
    guard case let .loading(id) = homeDetails else { return false }
    return id == pack?.id
  }

  func doneSummary(now: Date) -> DoneSummary? {
    guard hasSession, hasMySchedule, let liveBoard, let pack,
          let seoulTimeZone = TimeZone(identifier: "Asia/Seoul") else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = seoulTimeZone
    let entries = FestivalLiveBoardSchedule.entries(pack: pack)
    let lastPerformanceDay = entries.last?.slot.startsAt ?? now
    let seenSetCount = entries.filter { entry in
      mySetIDs.contains(entry.slot.id) &&
        calendar.isDate(
          entry.slot.startsAt,
          inSameDayAs: lastPerformanceDay
        ) &&
        (entry.slot.endsAt ?? entry.slot.startsAt) <= now
    }.count
    return DoneSummary(
      seenSetCount: seenSetCount,
      crewCount: liveBoard.crew?.members.count ?? 0,
      followedFlagCount: liveBoard.followedFlags.count
    )
  }

  private func timeText(_ value: String) -> String {
    guard let date = FestivalLiveBoardSchedule.parse(value) else { return value }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    return formatter.string(from: date)
  }

  private func walkText(_ minutes: Int?) -> String {
    return minutes.map { " (도보 \($0)분)" } ?? ""
  }

  private func nonempty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
  }
}
