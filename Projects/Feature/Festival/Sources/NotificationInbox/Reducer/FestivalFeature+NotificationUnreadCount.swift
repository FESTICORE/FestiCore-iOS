import ComposableArchitecture

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
          let page = try await userNotificationUseCase.notifications(before: nil)
          let latest = page.items.filter { $0.readAt == nil }.max { $0.createdAt < $1.createdAt }
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
