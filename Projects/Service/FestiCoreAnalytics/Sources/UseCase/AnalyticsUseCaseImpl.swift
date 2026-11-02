//
//  AnalyticsUseCaseImpl.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 11/2/26.
//

import FestiCoreAnalyticsInterface
import Mixpanel
import Sentry

/// Mixpanel에 이벤트를, Sentry에 같은 이름의 breadcrumb를 남긴다.
/// 토큰이나 DSN이 없어 SDK가 시작되지 않았으면 아무것도 보내지 않는다.
struct AnalyticsUseCaseImpl: AnalyticsUseCaseInterface {
  func track(_ event: AnalyticsEvent) {
    let properties = event.properties
    Mixpanel.safeMainInstance()?.track(
      event: event.name,
      properties: properties.mapValues { $0 as MixpanelType }
    )

    let breadcrumb = Breadcrumb(level: .info, category: event.breadcrumbCategory)
    breadcrumb.message = event.name
    breadcrumb.data = properties
    SentrySDK.addBreadcrumb(breadcrumb)
  }
}
