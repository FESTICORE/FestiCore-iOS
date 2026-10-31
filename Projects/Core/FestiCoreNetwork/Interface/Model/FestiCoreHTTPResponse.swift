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
  public let headers: [String: String]

  public init(statusCode: Int, data: Data, headers: [String: String] = [:]) {
    self.statusCode = statusCode
    self.data = data
    self.headers = headers
  }

  public func header(_ name: String) -> String? {
    headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
  }
}
