//
//  PackRuleTags.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 반입 금지 태그를 줄바꿈하며 나열한다.
struct PackRuleTags: View {
  let tags: [String]

  var body: some View {
    FCFlowLayout {
      ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
        FCTag(tag)
      }
    }
    // Figma Pack B Tags 간격 6
    .spacing(FestiCoreSpacing.marginM6)
  }
}
