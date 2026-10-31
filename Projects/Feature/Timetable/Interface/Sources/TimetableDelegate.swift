//
//  TimetableDelegate.swift
//  TimetableInterface
//
//  Created by FestiCore on 10/31/26.
//

import ComposableArchitecture

@CasePathable
public enum TimetableDelegate: Equatable, Sendable {
  case showChanges
  case search
  case requestNotification
  case scheduleSaved(festivalID: String, setIDs: Set<String>)
}
