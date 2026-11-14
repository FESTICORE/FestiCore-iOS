import Foundation

/// 앱이 실제 축제 데이터에서 만들어 Widget과 공유하는 읽기 전용 화면 스냅샷.
public struct FestivalWidgetSnapshot: Codable, Equatable, Sendable {
  public struct Performance: Codable, Equatable, Sendable {
    public let id: String
    public let artist: String
    public let stageName: String
    public let startsAt: Date
    public let endsAt: Date
    public let isSaved: Bool

    public init(
      id: String,
      artist: String,
      stageName: String,
      startsAt: Date,
      endsAt: Date,
      isSaved: Bool
    ) {
      self.id = id
      self.artist = artist
      self.stageName = stageName
      self.startsAt = startsAt
      self.endsAt = endsAt
      self.isSaved = isSaved
    }
  }

  /// 축제 하루. 위젯이 `DAY N`과 개장 시각(`15:00 개장`)을 보일 때 쓴다.
  public struct Day: Codable, Equatable, Sendable {
    /// 그날 00:00(KST)
    public let date: Date
    public let opensAt: Date?

    public init(
      date: Date,
      opensAt: Date?
    ) {
      self.date = date
      self.opensAt = opensAt
    }
  }

  public let festivalID: String
  public let festivalName: String
  public let firstDay: Date?
  public let lastDay: Date?
  public let updatedAt: Date
  public let hasPack: Bool
  public let performances: [Performance]
  public let leaveAt: Date?
  public let crewName: String?
  /// 축제 일자(날짜순). 이전 버전 스냅샷에는 없다.
  public let days: [Day]?

  public init(
    festivalID: String,
    festivalName: String,
    firstDay: Date?,
    lastDay: Date?,
    updatedAt: Date,
    hasPack: Bool,
    performances: [Performance],
    leaveAt: Date? = nil,
    crewName: String? = nil,
    days: [Day]? = nil
  ) {
    self.festivalID = festivalID
    self.festivalName = festivalName
    self.firstDay = firstDay
    self.lastDay = lastDay
    self.updatedAt = updatedAt
    self.hasPack = hasPack
    self.performances = performances
    self.leaveAt = leaveAt
    self.crewName = crewName
    self.days = days
  }

  public func withUpdatedAt(_ date: Date) -> Self {
    return Self(
      festivalID: festivalID,
      festivalName: festivalName,
      firstDay: firstDay,
      lastDay: lastDay,
      updatedAt: date,
      hasPack: hasPack,
      performances: performances,
      leaveAt: leaveAt,
      crewName: crewName,
      days: days
    )
  }
}
