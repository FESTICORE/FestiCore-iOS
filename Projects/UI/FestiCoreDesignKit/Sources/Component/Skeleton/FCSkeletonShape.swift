//
//  FCSkeletonShape.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 스켈레톤이 그릴 모양.
public enum FCSkeletonShape: Shape {
  case rect
  case round(cornerRadius: CGFloat = FestiCoreRadius.r12)
  case circle

  public func path(in rect: CGRect) -> Path {
    switch self {
    case .rect:
      return Rectangle().path(in: rect)
    case let .round(cornerRadius):
      return RoundedRectangle(cornerRadius: cornerRadius, style: .circular).path(in: rect)
    case .circle:
      return Circle().path(in: rect)
    }
  }
}
