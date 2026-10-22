//
//  FestiCoreHTTPResponse.swift
//  FestiCoreNetworkInterface
//
//  Created by FestiCore on 9/1/26.
//

import Foundation

public struct FestiCoreHTTPResponse: Sendable, Equatable {
  public let statusCode: Int
  public let data: Data

  public init(statusCode: Int, data: Data) {
    self.statusCode = statusCode
    self.data = data
  }
}
