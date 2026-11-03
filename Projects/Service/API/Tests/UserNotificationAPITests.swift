import API
import Testing

@Suite("내 알림 경로")
struct UserNotificationAPITests {
  @Test func paths() {
    #expect(UserNotificationAPI.list.path == "api/v1/me/notifications")
    #expect(UserNotificationAPI.unreadCount.path == "api/v1/me/notifications/unread-count")
    #expect(UserNotificationAPI.read.path == "api/v1/me/notifications/read")
    #expect(UserNotificationAPI.delete.path == "api/v1/me/notifications/delete")
  }
}
