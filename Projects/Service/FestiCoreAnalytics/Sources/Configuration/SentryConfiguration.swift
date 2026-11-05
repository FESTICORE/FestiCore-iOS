//
//  SentryConfiguration.swift
//  FestiCoreAnalytics
//
//  Created by FestiCore on 10/28/26.
//

import Foundation

import FestiCoreLogger
@preconcurrency import Sentry

/// Sentry 기동과 런치 메트릭 전송.
enum SentryConfiguration {
  struct Options: Equatable {
    let dsn: String
    let environment: String
  }

  /// DSN·환경은 xcconfig → Info.plist로 주입된 값을 읽는다. 둘 중 하나라도 유효하지 않으면 시작하지 않는다.
  static func options(infoDictionary: [String: Any]) -> Options? {
    guard let dsn = (infoDictionary["FestiCoreSentryDSN"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines), !dsn.isEmpty,
      let components = URLComponents(string: dsn),
      components.scheme == "https", components.host != nil,
      components.user != nil,
      Int(components.path.dropFirst()) != nil,
      let environment = infoDictionary["FestiCoreEnvironment"] as? String,
      environment == "stage" || environment == "production" else {
      return nil
    }
    return Options(
      dsn: dsn,
      environment: environment)
  }

  /// 가장 먼저 호출해 초기 크래시까지 포착한다.
  static func configure(infoDictionary: [String: Any]) {
    guard let configuration = options(infoDictionary: infoDictionary) else {
      let dsn = (infoDictionary["FestiCoreSentryDSN"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let reason = dsn.isEmpty ? "FESTICORE_SENTRY_DSN이 비어 있음" : "Sentry DSN 또는 환경 설정이 유효하지 않음"
      FestiCoreLogger.error(
        "Sentry 시작 건너뜀: \(reason)",
        category: .app
      )
      return
    }
    let environment = configuration.environment

    SentrySDK.start { options in
      options.dsn = configuration.dsn
      options.environment = environment
      options.sendDefaultPii = false

      #if DEBUG
        options.debug = true
      #else
        options.debug = false
      #endif

      options.releaseName = (infoDictionary["CFBundleShortVersionString"] as? String).map {
        "festicore-ios@\($0)+\((infoDictionary["CFBundleVersion"] as? String) ?? "")"
      }

      // 구조화 로그.
      options.enableLogs = true
      options.enableMetrics = true

      // 성능 트레이싱 + 프로파일링(트레이싱에 종속).
      options.tracesSampleRate = 0.2
      options.configureProfiling = {
        $0.lifecycle = .trace
        $0.sessionSampleRate = 1.0
      }

      options.enableTimeToFullDisplayTracing = true
      options.enableMetricKit = true
      options.swiftAsyncStacktraces = true

      options.enableSwizzling = true
      options.enableAutoPerformanceTracing = true
      options.enableNetworkTracking = true
      options.enableNetworkBreadcrumbs = true

      // 안정성 모니터링 활성화.
      // 앱 행(ANR): 완전 차단뿐 아니라 부분 차단(비블로킹)까지 리포트, 임계 2초.
      options.appHangTimeoutInterval = 2.0
      // 워치독 강제종료(OOM 등) 추적.
      options.enableWatchdogTerminationTracking = true
      // 세션(안정성/Crash-Free) 지표 자동 추적.
      options.enableAutoSessionTracking = true
      options.sessionTrackingIntervalMillis = 30000
      // 콜드 스타트 정확도(프리웜 구간 반영) + UI 인터랙션 자동 트랜잭션.
      options.enablePreWarmedAppStartTracing = true
      options.enableUserInteractionTracing = true
      // 크래시 순간 진행 중이던 트레이스를 보존해 유실 방지.
      options.enablePersistingTracesWhenCrashing = true

      options.enableCaptureFailedRequests = true
      options.failedRequestStatusCodes = [
        HttpStatusCodeRange(
          min: 400,
          max: 599
        )
      ]

      // 크래시 컨텍스트 첨부.
      options.attachScreenshot = true
      options.attachViewHierarchy = false

      // Session Replay는 쓰지 않는다. 켜더라도 텍스트·이미지는 가린다.
      options.sessionReplay.maskAllText = true
      options.sessionReplay.maskAllImages = true
      options.sessionReplay.sessionSampleRate = 0.0
      options.sessionReplay.onErrorSampleRate = 0.0
    }

    sendSentryVerificationTelemetry(environment: environment)
    emitLaunchMetrics(environment: environment)
  }

  /// 앱 실행 시 기기·런타임 메트릭을 환경 태깅해 전송한다(모든 빌드).
  /// 런치당 1회라 볼륨이 낮고, 카운트·게이지로 지표 유형을 나눴다.
  private static func emitLaunchMetrics(environment: String) {
    let process = ProcessInfo.processInfo
    let attributes: [String: any SentryAttributeValue] = [
      "environment": environment,
      "source": "app_launch"
    ]
    let memoryMB = Double(process.physicalMemory) / 1_048_576.0

    // 카운트: 앱 실행 횟수(리텐션/DAU 보조 지표).
    SentrySDK.metrics.count(
      key: "app.launch.count",
      value: 1,
      attributes: attributes)
    // 게이지: 실행 시점 기기 리소스 스냅샷.
    SentrySDK.metrics.gauge(
      key: "app.device.memory_total_mb",
      value: memoryMB,
      attributes: attributes)
    SentrySDK.metrics.gauge(
      key: "app.device.processor_count",
      value: Double(process.activeProcessorCount),
      attributes: attributes
    )
    SentrySDK.metrics.gauge(
      key: "app.device.thermal_state",
      value: Double(process.thermalState.rawValue),
      attributes: attributes
    )
    SentrySDK.metrics.gauge(
      key: "app.device.low_power_mode",
      value: process.isLowPowerModeEnabled ? 1 : 0,
      attributes: attributes
    )
  }

  /// Sentry 연동 검증용 로그·메트릭. DEBUG(Stage) 빌드에서만 전송해 운영 데이터 오염을 막는다.
  private static func sendSentryVerificationTelemetry(environment: String) {
    #if DEBUG
      let logAttributes: [String: Any] = [
        "log_type": "test",
        "environment": environment,
        "source": "app_launch"
      ]
      let metricAttributes: [String: any SentryAttributeValue] = [
        "log_type": "test",
        "environment": environment,
        "source": "app_launch"
      ]

      SentrySDK.logger.info(
        "Sending a test info log",
        attributes: logAttributes
      )
      SentrySDK.logger.warn(
        "Sending a test warning log",
        attributes: logAttributes
      )

      SentrySDK.metrics.count(
        key: "app.launch.count",
        value: 1,
        attributes: metricAttributes
      )
      SentrySDK.metrics.gauge(
        key: "app.launch.queue_depth",
        value: 1.0,
        attributes: metricAttributes
      )
      SentrySDK.metrics.distribution(
        key: "app.launch.verification_time",
        value: 1.0,
        unit: .millisecond,
        attributes: metricAttributes
      )
    #endif
  }
}
