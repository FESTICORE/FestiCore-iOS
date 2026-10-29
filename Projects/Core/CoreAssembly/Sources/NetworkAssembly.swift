//
//  NetworkAssembly.swift
//  CoreAssembly
//
//  Created by FestiCore on 10/23/26.
//

import FestiCoreNetwork
import FestiCoreNetworkInterface

public enum NetworkAssembly {
  public static func webSocketClient() -> any FestiCoreWebSocketClient {
    return NetworkClientFactory.webSocket()
  }

  public static func plainClient() -> any FestiCoreNetworkClient {
    NetworkClientFactory.plain()
  }
}
