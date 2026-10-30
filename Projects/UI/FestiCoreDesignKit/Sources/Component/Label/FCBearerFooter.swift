//
//  FCBearerFooter.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 기수 보드 맨 아래 안내 줄. queued는 오프라인에서 누른 변경이 전송 대기 중인 상태다.
public struct FCBearerFooter: View {
  /// 0이면 기본 안내, 1 이상이면 전송 대기 건수를 표시한다.
  private var queuedCount: Int
  private(set) var message: String?

  public init(queuedCount: Int = 0) {
    self.queuedCount = queuedCount
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.marginM6) {
      Image(asset: isQueued ? .clock16 : .circleInfo16)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .accessibilityHidden(true)
      Text(message ?? (isQueued ? "보내기 대기 \(queuedCount)건 · 연결되면 자동으로 보내요" : "오프라인이어도 눌러져요 · 연결되면 자동으로 보내요"))
        .festiCoreFont(.baseFootnoteRegular)
    }
    .foregroundStyle(isQueued ? FestiCoreSemanticColor.labelNormal.color : FestiCoreSemanticColor.labelAssistive.color)
    .padding(.vertical, FestiCoreSpacing.paddingP12)
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
  }

}

private extension FCBearerFooter {
  var isQueued: Bool {
    queuedCount > 0
  }
}

// MARK: - 체이닝 설정

public extension FCBearerFooter {
  /// 안내 문구를 바꾼 사본을 돌려준다. `nil`이면 상태별 기본 문구를 쓴다.
  func message(_ message: String?) -> Self {
    var copy = self
    copy.message = message
    return copy
  }
}

private extension FCBearerFooter {
  enum Metric {
    static let iconSize: CGFloat = 16
  }
}

#Preview {
  VStack(spacing: FestiCoreSpacing.paddingP8) {
    FCBearerFooter()
    FCBearerFooter(queuedCount: 1)
  }
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
