//
//  NotificationService.swift
//  FestiCoreNotificationService
//
//  Created by FestiCore on 10/26/26.
//

import FestiCoreUtility
import Foundation
import UserNotifications

/// 앱이 꺼져 있어도 `mutable-content` 알림에 축제 묶음·부제목·포스터를 붙인다.
/// 시간이 끝나면 지금까지 보강한 내용을 그대로 보인다.
final class NotificationService: UNNotificationServiceExtension, @unchecked Sendable {
  private let lock = NSLock()
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttempt: UNMutableNotificationContent?
  private var downloadTask: URLSessionDownloadTask?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
      contentHandler(request.content)
      return
    }
    let enrichment = RemoteNotificationEnrichment(userInfo: content.userInfo)
    if let thread = enrichment.threadIdentifier(current: content.threadIdentifier) {
      content.threadIdentifier = thread
    }
    if let subtitle = enrichment.subtitle(current: content.subtitle) {
      content.subtitle = subtitle
    }
    lock.withLock {
      self.contentHandler = contentHandler
      bestAttempt = content
    }
    guard let imageURL = enrichment.imageURL else {
      deliver()
      return
    }
    let task = URLSession.shared.downloadTask(with: imageURL) { [weak self] location, response, _ in
      self?.attach(
        location: location,
        response: response
      )
      self?.deliver()
    }
    lock.withLock { downloadTask = task }
    task.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    lock.withLock { downloadTask }?.cancel()
    deliver()
  }
}

private extension NotificationService {
  /// 알림 첨부 이미지 상한(10MB)을 넘지 않는 JPEG·PNG·GIF만 붙인다.
  func attach(
    location: URL?,
    response: URLResponse?
  ) {
    guard let location,
          let http = response as? HTTPURLResponse,
          (200..<300).contains(http.statusCode),
          let fileExtension = RemoteNotificationEnrichment.attachmentFileExtension(mimeType: http.mimeType),
          let size = try? location.resourceValues(forKeys: [.fileSizeKey]).fileSize,
          size > 0,
          size <= 10 * 1024 * 1024 else { return }
    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(fileExtension)
    do {
      try FileManager.default.moveItem(
        at: location,
        to: destination
      )
      let attachment = try UNNotificationAttachment(
        identifier: "image",
        url: destination
      )
      lock.withLock { bestAttempt?.attachments = [attachment] }
    } catch {
      try? FileManager.default.removeItem(at: destination)
    }
  }

  /// 다운로드 완료와 시간 만료가 겹쳐도 한 번만 전달한다.
  func deliver() {
    let delivery: (() -> Void)? = lock.withLock {
      guard let contentHandler, let bestAttempt else { return nil }
      self.contentHandler = nil
      return { contentHandler(bestAttempt) }
    }
    delivery?()
  }
}
