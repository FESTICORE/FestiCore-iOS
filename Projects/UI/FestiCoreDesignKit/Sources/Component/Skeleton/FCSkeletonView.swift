//
//  FCSkeletonView.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 데이터를 기다리는 동안 보이는 자리. 밝은 띠가 1초 주기로 지나가며, 동작 줄이기 설정이면 멈춘다.
public struct FCSkeletonView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let shape: FCSkeletonShape

  public init(_ shape: FCSkeletonShape) {
    self.shape = shape
  }

  public var body: some View {
    shape
      .fill(FestiCoreSemanticColor.fillStrong.color)
      .overlay {
        if !reduceMotion {
          shimmer
        }
      }
      .clipShape(shape)
      .compositingGroup()
      .accessibilityLabel("불러오는 중")
  }
}

private extension FCSkeletonView {
  var shimmer: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let bandWidth = size.width / 2
      let blurRadius = max(bandWidth / 2, Metric.minimumBlurRadius)
      let blurDiameter = blurRadius * 2
      let minX = -(bandWidth + blurDiameter)
      let maxX = size.width + bandWidth + blurDiameter
      TimelineView(.animation) { timeline in
        Rectangle()
          .fill(FestiCoreSemanticColor.staticWhite.color)
          .frame(width: bandWidth, height: size.height * 2)
          .frame(height: size.height)
          .blur(radius: blurRadius)
          .rotationEffect(.degrees(Metric.rotation))
          .blendMode(.softLight)
          .offset(x: minX + (maxX - minX) * phase(at: timeline.date))
      }
    }
  }

  func phase(at date: Date) -> Double {
    date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Metric.period) / Metric.period
  }
}

public extension View {
  /// 로딩 중에는 원본을 숨기고 스켈레톤을 보인다.
  /// 데이터가 오기 전 원본이 비어 크기를 잃는 경우 `width`·`height`로 자리를 빌려준다.
  func skeleton(
    isLoading: Bool,
    shape: FCSkeletonShape,
    width: CGFloat? = nil,
    height: CGFloat? = nil
  ) -> some View {
    modifier(
      FCSkeletonModifier(
        isLoading: isLoading,
        shape: shape,
        width: width,
        height: height
      )
    )
  }
}

private struct FCSkeletonModifier: ViewModifier {
  let isLoading: Bool
  let shape: FCSkeletonShape
  let width: CGFloat?
  let height: CGFloat?

  func body(content: Content) -> some View {
    ZStack {
      content
        .opacity(isLoading ? 0 : 1)
      if isLoading {
        FCSkeletonView(shape)
          .frame(width: width, height: height)
          .transition(.opacity)
      }
    }
    .fixedSize(horizontal: isLoading && width != nil, vertical: isLoading && height != nil)
    .animation(.easeInOut(duration: Metric.fadeDuration), value: isLoading)
  }
}

private enum Metric {
  static let rotation: Double = 5
  static let period: Double = 1
  static let minimumBlurRadius: CGFloat = 30
  static let fadeDuration: Double = 0.2
}

#Preview {
  @Previewable
  @State var isLoading = true

  VStack(spacing: FestiCoreSpacing.paddingP12) {
    Text("페스티벌 이름")
      .skeleton(
        isLoading: isLoading,
        shape: .round(),
        width: 200,
        height: 24
      )
    FCSkeletonView(.circle)
      .frame(width: 40, height: 40)
    Button("전환") { isLoading.toggle() }
  }
  .padding(FestiCoreSpacing.paddingP20)
}
