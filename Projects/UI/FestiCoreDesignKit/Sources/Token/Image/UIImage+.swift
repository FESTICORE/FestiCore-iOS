//
//  UIImage+.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/23/26.
//

import SwiftUI

public extension UIImage {
  convenience init?(_ asset: ImageAsset) {
    self.init(assetName: asset.rawValue)
  }

  convenience init?(assetName: String) {
    self.init(named: assetName, in: .module, with: nil)
  }
}

public extension Image {
  init(asset: ImageAsset) {
    self.init(assetName: asset.rawValue)
  }

  init(assetName: String) {
    if let image = UIImage(assetName: assetName) {
      self.init(uiImage: image)
    } else {
      self = Image(systemName: "questionmark")
        .renderingMode(.template)
    }
  }
}
