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
  let liveActivityState: FestivalFeature.LiveActivityControlState
  let showsLiveActivityControl: Bool
  let showsFollowGuide: Bool

  init(state: FestivalFeature.State) {
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
    liveActivityState = state.liveActivityState
    showsLiveActivityControl = state.showsLiveActivityControl
    showsFollowGuide = state.showsFollowGuide
  }

  func homeRide(now: Date) -> HomeRide? {
    guard let festivalID = pack?.id,
          let directions = homeDetails.directions(for: festivalID) else { return nil }
    let shuttleAt = nonempty(directions.lastShuttleAt)
    let trainAt = nonempty(directions.lastTrainAt)
    let trainDate = trainAt.flatMap { departureDate(
      $0,
      now: now
    ) }
    let shuttleDate = shuttleAt.flatMap { departureDate(
      $0,
      now: now
    ) }
    let departure: (name: String, date: Date)
    if let trainDate, trainDate > now {
      departure = ("막차", trainDate)
    } else if let shuttleDate, shuttleDate > now {
      departure = ("셔틀", shuttleDate)
    } else {
      return nil
    }
    let minutes = Int(ceil(departure.date.timeIntervalSince(now) / 60))
    guard minutes > 0 else { return nil }
    let shuttleStation = directions.shuttle?.stationName.map { " · \($0)" } ?? ""
    let trainStation = directions.transit?.stationName.map { " · \($0)" } ?? ""
    let walkMinutes = directions.transit?.walkMinutes.map { " (도보 \($0)분)" } ?? ""
    return HomeRide(
      remain: "\(departure.name)까지 \(minutes)분",
      shuttle: shuttleAt.map { "마지막 셔틀 \(timeText($0))\(shuttleStation)" } ?? "셔틀 시간 미공개",
      train: trainAt.map { "막차 \(timeText($0))\(trainStation)\(walkMinutes)" } ?? "막차 시간 미공개"
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

  private func departureDate(
    _ value: String,
    now: Date
  ) -> Date? {
    if let date = FestivalLiveBoardSchedule.parse(value) { return date }
    let parts = value.split(separator: ":")
    guard parts.count == 2,
          let hour = Int(parts[0]), (0...23).contains(hour),
          let minute = Int(parts[1]), (0...59).contains(minute),
          let seoulTimeZone = TimeZone(identifier: "Asia/Seoul") else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = seoulTimeZone
    guard let sameDay = calendar.date(
      bySettingHour: hour,
      minute: minute,
      second: 0,
      of: now
    ) else { return nil }
    if sameDay <= now, hour < 6, calendar.component(
      .hour,
      from: now
    ) >= 18 {
      return calendar.date(
        byAdding: .day,
        value: 1,
        to: sameDay
      )
    }
    return sameDay
  }

  private func timeText(_ value: String) -> String {
    guard let date = FestivalLiveBoardSchedule.parse(value) else { return value }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    return formatter.string(from: date)
  }

  private func nonempty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
  }
}
