//
//  ImageAsset.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/23/26.
//

public struct ImageAsset: RawRepresentable, Hashable, Sendable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}
