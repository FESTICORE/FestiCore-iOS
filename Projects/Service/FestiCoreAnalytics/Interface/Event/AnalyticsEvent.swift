//
//  AnalyticsEvent.swift
//  FestiCoreAnalyticsInterface
//
//  Created by FestiCore on 11/2/26.
//

/// Feature가 분석 도구로 보내는 이벤트.
public enum AnalyticsEvent: Equatable, Sendable {
  case screenView(AnalyticsScreen)
}
