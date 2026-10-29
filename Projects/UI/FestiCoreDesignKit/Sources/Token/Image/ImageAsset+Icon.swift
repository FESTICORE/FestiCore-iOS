//
//  ImageAsset+Icon.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

/// Figma Design System - Component의 Icon·Logo 컴포넌트를 SVG로 내보낸 에셋이다.
public extension ImageAsset {
  static let logo = ImageAsset(rawValue: "logo")
  static let bell = ImageAsset(rawValue: "bell")
  static let check = ImageAsset(rawValue: "check")
  static let chevronLeft = ImageAsset(rawValue: "chevron-left")
  static let circleXmark = ImageAsset(rawValue: "circle-xmark")
  static let flag16 = ImageAsset(rawValue: "flag-16")
  static let magnifyingGlass = ImageAsset(rawValue: "magnifying-glass")
  static let magnifyingGlass16 = ImageAsset(rawValue: "magnifying-glass-16")
  static let chevronLeft16 = ImageAsset(rawValue: "chevron-left-16")
  static let chevronRight16 = ImageAsset(rawValue: "chevron-right-16")
  static let filter16 = ImageAsset(rawValue: "filter-16")
  static let flag = ImageAsset(rawValue: "flag")
  static let locationDot = ImageAsset(rawValue: "location-dot")

  // MARK: - 소셜 로그인

  static let appleLogo = ImageAsset(rawValue: "apple-logo")
  static let googleLogo = ImageAsset(rawValue: "google-logo")

  // MARK: - 탭 바

  static let navHomeActive = ImageAsset(rawValue: "nav-home-active")
  static let navHomeInactive = ImageAsset(rawValue: "nav-home-inactive")
  static let navTimetableActive = ImageAsset(rawValue: "nav-timetable-active")
  static let navTimetableInactive = ImageAsset(rawValue: "nav-timetable-inactive")
  static let navFlagActive = ImageAsset(rawValue: "nav-flag-active")
  static let navFlagInactive = ImageAsset(rawValue: "nav-flag-inactive")
  static let navMyActive = ImageAsset(rawValue: "nav-my-active")
  static let navMyInactive = ImageAsset(rawValue: "nav-my-inactive")
}
