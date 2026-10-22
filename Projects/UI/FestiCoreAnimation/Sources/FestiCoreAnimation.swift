//
//  FestiCoreAnimation.swift
//  FestiCoreAnimation
//
//  Created by FestiCore on 10/22/26.
//

import SwiftUI
import SDWebImageSwiftUI

/// Displays an animated image from a caller supplied bundle and asset name.
public struct FestiCoreAnimationView: View {
  private let name: String
  private let bundle: Bundle
  private let isAnimating: Binding<Bool>

  public init(name: String, bundle: Bundle, isAnimating: Binding<Bool> = .constant(true)) {
    self.name = name
    self.bundle = bundle
    self.isAnimating = isAnimating
  }

  public var body: some View {
    AnimatedImage(name: name, bundle: bundle, isAnimating: isAnimating)
      .resizable()
      .scaledToFit()
  }
}
