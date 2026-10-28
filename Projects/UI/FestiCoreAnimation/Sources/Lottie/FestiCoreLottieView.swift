//
//  FestiCoreLottieView.swift
//  FestiCoreAnimation
//
//  Created by FestiCore on 10/27/26.
//

import Lottie
import SwiftUI

/// 로컬 JSON 또는 HTTPS 애니메이션을 반복 재생합니다.
public struct FestiCoreLottieView: View {
  private let source: FestiCoreLottieSource
  private(set) var targetDuration: TimeInterval?

  @State private var remoteAnimation: LottieAnimation?
  @State private var remoteDotLottieFile: DotLottieFile?
  @State private var loadedSourceID: String?
  @State private var failedSourceID: String?

  public init(_ source: FestiCoreLottieSource) {
    self.source = source
  }

  public init(_ asset: FestiCoreAnimationAsset) {
    source = .asset(name: asset.rawValue, bundle: Bundle(for: FestiCoreAnimationBundleMarker.self))
  }

  /// 애니메이션 한 번의 목표 재생 시간을 초 단위로 지정합니다.
  public func duration(_ seconds: TimeInterval) -> Self {
    guard seconds.isFinite, seconds > 0 else { return self }
    var copy = self
    copy.targetDuration = seconds
    return copy
  }

  public var body: some View {
    switch source {
    case let .asset(name, bundle):
      if let animation = LottieAnimation.named(name, bundle: bundle) {
        LottieView(animation: animation)
          .looping()
          .animationSpeed(speed(for: animation.duration))
          .resizable()
      } else {
        failureView
      }

    case let .remote(url, format):
      ZStack {
        if !source.isValidRemoteSource || failedSourceID == taskID(url: url, format: format) {
          failureView
        } else if loadedSourceID == taskID(url: url, format: format), let animation = remoteAnimation {
          LottieView(animation: animation)
            .looping()
            .animationSpeed(speed(for: animation.duration))
            .resizable()
        } else if loadedSourceID == taskID(url: url, format: format), let file = remoteDotLottieFile {
          LottieView(dotLottieFile: file)
            .looping()
            // .lottie 파일은 여러 애니메이션을 담을 수 있어 실제 재생 중인 길이를 사용한다.
            .configure { view in
              if let speed = speedOverride(for: view.animation?.duration), view.animationSpeed != speed {
                view.animationSpeed = speed
              }
            }
            .resizable()
        } else {
          ProgressView()
        }
      }
      .task(id: taskID(url: url, format: format)) { await load(url: url, format: format) }
    }
  }

  private var failureView: some View {
    Image(systemName: "exclamationmark.triangle")
      .foregroundStyle(.secondary)
      .accessibilityLabel("애니메이션을 불러올 수 없습니다")
  }

  func speed(for intrinsicDuration: TimeInterval?) -> Double {
    speedOverride(for: intrinsicDuration) ?? 1
  }

  func speedOverride(for intrinsicDuration: TimeInterval?) -> Double? {
    guard let targetDuration,
          let intrinsicDuration,
          intrinsicDuration.isFinite,
          intrinsicDuration > 0 else { return nil }
    let result = intrinsicDuration / targetDuration
    return result.isFinite && result > 0 ? result : nil
  }

  func taskID(url: URL, format: FestiCoreLottieFormat) -> String {
    "\(url.absoluteString):\(format)"
  }

  private func load(url: URL, format: FestiCoreLottieFormat) async {
    guard source.isValidRemoteSource else { return }
    let sourceID = taskID(url: url, format: format)
    loadedSourceID = nil
    failedSourceID = nil

    switch format {
    case .json:
      let animation = await LottieAnimation.loadedFrom(url: url)
      guard !Task.isCancelled else { return }
      remoteAnimation = animation
      remoteDotLottieFile = nil
      loadedSourceID = animation == nil ? nil : sourceID
      failedSourceID = animation == nil ? sourceID : nil
    case .dotLottie:
      do {
        let file = try await DotLottieFile.loadedFrom(url: url)
        guard !Task.isCancelled else { return }
        remoteDotLottieFile = file
        remoteAnimation = nil
        loadedSourceID = file.animations.isEmpty ? nil : sourceID
        failedSourceID = file.animations.isEmpty ? sourceID : nil
      } catch {
        guard !Task.isCancelled else { return }
        remoteAnimation = nil
        remoteDotLottieFile = nil
        loadedSourceID = nil
        failedSourceID = sourceID
      }
    }
  }
}
