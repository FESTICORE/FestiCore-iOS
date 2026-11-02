//
//  FestivalAccessibilityID.swift
//  Festival
//
//  Created by FestiCore on 11/2/26.
//

/// Festival 화면의 UI 테스트·접근성 식별자
enum FestivalAccessibilityID {
  static let listSkeleton = "festivalListSkeleton"
  static let liveBoardSkeleton = "festivalLiveBoardSkeleton"

  static func card(_ festivalID: String) -> String {
    "festivalCard_\(festivalID)"
  }
}
