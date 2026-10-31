//
//  FestivalDelegate.swift
//  FestivalInterface
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture

@CasePathable
public enum FestivalDelegate: Equatable, Sendable {
  case bookmarkRequested(String)
  case loginRequested
}
