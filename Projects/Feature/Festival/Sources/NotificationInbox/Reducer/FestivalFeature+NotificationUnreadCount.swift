import ComposableArchitecture
import Foundation

extension FestivalFeature {
  func markNotificationRead(
    _ id: String,
    state: State
  ) -> Effect<Action> {
    guard state.hasSession else { return .none }
    return .run { send in
      // 이동한 화면이 알림함을 닫아도 보드가 읽음 요청을 끝까지 소유한다.
      try? await userNotificationUseCase.markRead(ids: [id])
      await send(.async(.loadNotificationUnreadCount))
    }
    .cancellable(id: CancelID.notificationMarkRead)
  }

  /// 상단 배너는 이 시간 안에 온 안 읽은 알림만 띄운다. 오래된 알림은 배지와 알림함에만 남긴다.
  /// 서버 시계가 조금 앞서 미래 시각으로 온 방금 알림도 배너로 띄운다.
  static let notificationBannerLifetime: TimeInterval = 24 * 60 * 60

  /// 공연 시작 알림("10분 후 시작")은 공연이 시작되면 뜻이 없어 배너에 짧게만 띄운다.
  static let setReminderBannerLifetime: TimeInterval = 30 * 60

  static func bannerLifetime(for type: String) -> TimeInterval {
    return type == "festival.set_reminder" ? setReminderBannerLifetime : notificationBannerLifetime
  }

  func loadNotificationUnreadCount(_ state: State) -> Effect<Action> {
    guard state.hasSession else { return .none }
    let generation = state.accountGeneration
    return .run { send in
      do {
        let count = try await userNotificationUseCase.unreadCount()
        await send(.inner(.notificationUnreadCountLoaded(
          count,
          generation: generation
        )))
        if count > 0 {
          let now = date.now
          let page = try await userNotificationUseCase.notifications(before: nil)
          let latest = page.items
            .filter { item in
              return item.readAt == nil
                && now.timeIntervalSince(item.createdAt) < Self.bannerLifetime(for: item.type)
            }
            .max { $0.createdAt < $1.createdAt }
          await send(.inner(.notificationBannerLoaded(
            latest,
            generation: generation
          )))
        }
      } catch {
        // 연결 실패는 마지막으로 확인된 배지 상태를 유지한다.
      }
    }
    .cancellable(
      id: CancelID.notificationUnreadCount,
      cancelInFlight: true
    )
  }
}
