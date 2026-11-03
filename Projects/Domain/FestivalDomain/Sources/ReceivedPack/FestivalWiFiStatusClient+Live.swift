//
//  FestivalWiFiStatusClient+Live.swift
//  FestivalDomain
//
//  Created by FestiCore on 11/3/26.
//

import Dependencies
import FestivalDomainInterface
import Foundation
import Network

extension FestivalWiFiStatusClient: DependencyKey {
  public static let liveValue = Self(isOnWiFi: {
    await withCheckedContinuation { continuation in
      let monitor = NWPathMonitor()
      let resumed = LockIsolated(false)
      monitor.pathUpdateHandler = { path in
        // 첫 경로만 확인하고 감시를 멈춘다.
        guard !resumed.value else { return }
        resumed.setValue(true)
        monitor.cancel()
        // 개인 핫스팟처럼 비싸거나 저데이터 모드인 연결에서는 받지 않는다.
        continuation.resume(
          returning: path.status == .satisfied && path.usesInterfaceType(.wifi)
            && !path.isExpensive && !path.isConstrained
        )
      }
      monitor.start(queue: DispatchQueue(label: "io.festiCore.co.wifi-status"))
    }
  })
}
