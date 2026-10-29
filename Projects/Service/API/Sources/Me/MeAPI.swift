//
//  MeAPI.swift
//  API
//
//  Created by FestiCore on 10/29/26.
//

public enum MeAPI: String, CaseIterable, Sendable {
  case me

  public var path: String { "api/v1/\(rawValue)" }
}
