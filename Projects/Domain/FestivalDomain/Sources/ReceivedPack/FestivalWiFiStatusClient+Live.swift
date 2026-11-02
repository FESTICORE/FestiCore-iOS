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
        continuation.resume(returning: path.status == .satisfied && path.usesInterfaceType(.wifi))
      }
      monitor.start(queue: DispatchQueue(label: "io.festiCore.co.wifi-status"))
    }
  })
}
