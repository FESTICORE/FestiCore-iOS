//
//  FestivalFlagReportReason.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/8/26.
//

/// 깃발 신고 사유. 서버 `POST flags/:flagId/report`의 reason 값과 같다.
public enum FestivalFlagReportReason: String, CaseIterable, Equatable, Sendable {
  /// 가짜 깃발
  case fake
  /// 부적절한 사진이나 소개
  case inappropriate
  /// 기타
  case other
}
