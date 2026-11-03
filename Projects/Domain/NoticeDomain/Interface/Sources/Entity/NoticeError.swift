//
//  NoticeError.swift
//  NoticeDomainInterface
//

public enum NoticeError: Error, Equatable, Sendable {
  case invalidResponse
  case unavailable
}
