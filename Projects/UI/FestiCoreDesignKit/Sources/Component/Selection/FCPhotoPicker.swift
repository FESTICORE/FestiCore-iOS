//
//  FCPhotoPicker.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 깃발 사진 1장 고르기. 업로드 중에는 진행률과 취소 버튼을 표시한다.
public struct FCPhotoPicker: View {
  public enum State {
    case empty
    /// `progress`는 0...1
    case uploading(image: Image, progress: Double)
    case filled(Image)
  }

  private var state: State
  private var action: () -> Void
  private(set) var title = "깃발 사진"

  public init(_ state: State, action: @escaping () -> Void) {
    self.state = state
    self.action = action
  }

  public var body: some View {
    HStack(spacing: FestiCoreSpacing.paddingP16) {
      photo
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(title)
          .festiCoreFont(.baseBodyBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text(description)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        FCButton(buttonTitle, action: action)
          .style(.secondary)
          .size(.medium)
          .padding(.top, FestiCoreSpacing.paddingP4)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private var photo: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    switch state {
    case .empty:
      Image(asset: .camera)
        .resizable()
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .frame(width: Metric.photoSize, height: Metric.photoSize)
        .background(FestiCoreSemanticColor.fillNormal.color, in: shape)
        .overlay { shape.strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: Metric.borderWidth) }
        .accessibilityHidden(true)
    case let .uploading(image, progress):
      let clamped = min(max(progress, 0), 1)
      thumbnail(image)
        .overlay {
          ZStack {
            FestiCoreSemanticColor.staticalphaBlack60.color
            VStack(spacing: FestiCoreSpacing.paddingP8) {
              Text("\(Int(clamped * 100))%")
                .festiCoreFont(.baseSubheadlineBold)
                .foregroundStyle(FestiCoreSemanticColor.staticalphaWhite80.color)
                .monospacedDigit()
              Capsule()
                .fill(FestiCoreSemanticColor.staticalphaWhite20.color)
                .frame(width: Metric.progressWidth, height: Metric.progressHeight)
                .overlay(alignment: .leading) {
                  Capsule()
                    .fill(FestiCoreSemanticColor.staticLime.color)
                    .frame(width: Metric.progressWidth * clamped)
                }
            }
          }
        }
        .clipShape(shape)
        .accessibilityElement()
        .accessibilityLabel("업로드 중")
        .accessibilityValue("\(Int(clamped * 100))퍼센트")
    case let .filled(image):
      thumbnail(image)
        .clipShape(shape)
        .accessibilityHidden(true)
    }
  }

  private func thumbnail(_ image: Image) -> some View {
    image
      .resizable()
      .scaledToFill()
      .frame(width: Metric.photoSize, height: Metric.photoSize)
  }

  private var description: String {
    switch state {
    case .empty: return "깃발이 잘 보이는 사진 1장 · 정사각형으로 잘려요"
    case .uploading: return "사진을 올리고 있어요. 잠시만요"
    case .filled: return "깃발 목록과 상세 화면에 보여요"
    }
  }

  private var buttonTitle: String {
    switch state {
    case .empty: return "사진 고르기"
    case .uploading: return "취소"
    case .filled: return "바꾸기"
    }
  }
}

// MARK: - 체이닝 설정

public extension FCPhotoPicker {
  /// 제목을 바꾼 사본을 돌려준다.
  func title(_ title: String) -> Self {
    var copy = self
    copy.title = title
    return copy
  }
}

private extension FCPhotoPicker {
  enum Metric {
    static let photoSize: CGFloat = 88
    static let iconSize: CGFloat = 24
    static let borderWidth: CGFloat = 1
    static let progressWidth: CGFloat = 52
    static let progressHeight: CGFloat = 4
  }
}

#Preview {
  let sample = Image(systemName: "photo")
  VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP24) {
    FCPhotoPicker(.empty) {}
    FCPhotoPicker(.uploading(image: sample, progress: 0.64)) {}
    FCPhotoPicker(.filled(sample)) {}
  }
  .padding(FestiCoreSpacing.paddingP24)
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
