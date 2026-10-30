//
//  FCBearerChoiceSheet.swift
//  FestiCoreSharedUI
//
//  Created by FestiCore on 10/30/26.
//

import FestiCoreDesignKit
import SwiftUI

/// 기수 보드에서 존·활동을 고르는 바텀시트 내용. 누르면 바로 반영한다.
public struct FCBearerChoiceSheet: View {
  public enum Kind: Sendable {
    /// 존 선택. 작은 타일
    case zone
    /// 활동 선택. 큰 타일
    case activity
  }

  public struct Option: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let icon: ImageAsset

    public init(
      id: String,
      title: String,
      icon: ImageAsset
    ) {
      self.id = id
      self.title = title
      self.icon = icon
    }
  }

  private var kind: Kind
  private var options: [Option]
  private var selectedID: String?
  private var onSelect: (Option) -> Void
  private(set) var title: String
  private(set) var message: String

  public init(
    _ kind: Kind,
    options: [Option],
    selectedID: String?,
    onSelect: @escaping (Option) -> Void
  ) {
    self.kind = kind
    self.options = options
    self.selectedID = selectedID
    self.onSelect = onSelect
    switch kind {
    case .zone:
      title = "지금 어느 존에 있나요?"
      message = "누르면 장소 정보가 바로 바뀌고 팔로워에게 알림이 가요"
    case .activity:
      title = "지금 뭐 하고 있나요?"
      message = "누르면 바로 바뀌어요"
    }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(title)
          .festiCoreFont(.baseTitle2Bold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .accessibilityAddTraits(.isHeader)
        Text(message)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      LazyVGrid(
        columns: Array(
          repeating: GridItem(
            .flexible(),
            spacing: FestiCoreSpacing.paddingP12
          ),
          count: 2
        ),
        spacing: FestiCoreSpacing.paddingP12
      ) {
        ForEach(options) { option in
          tile(option)
        }
      }
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .padding(.bottom, FestiCoreSpacing.paddingP16)
  }

  private func tile(_ option: Option) -> some View {
    let isSelected = option.id == selectedID

    return Button {
      onSelect(option)
    } label: {
      tileContent(option)
        .foregroundStyle(
          isSelected
            ? FestiCoreSemanticColor.inverseLabel.color
            : FestiCoreSemanticColor.labelNormal.color
        )
        .frame(maxWidth: .infinity)
        .frame(height: kind == .zone ? Metric.zoneHeight : Metric.activityHeight)
        .background(
          isSelected
            ? FestiCoreSemanticColor.inverseBackground.color
            : FestiCoreSemanticColor.backgroundElevated.color,
          in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
        )
        .overlay {
          if !isSelected {
            RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
              .strokeBorder(FestiCoreSemanticColor.lineNormal.color)
          }
        }
        .contentShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(option.title)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  @ViewBuilder
  private func tileContent(_ option: Option) -> some View {
    switch kind {
    case .zone:
      HStack(spacing: FestiCoreSpacing.marginM6) {
        Image(asset: option.icon)
          .resizable()
          .frame(width: Metric.zoneIconSize, height: Metric.zoneIconSize)
        Text(option.title)
          .festiCoreFont(.baseFootnoteMedium)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP12)

    case .activity:
      VStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(asset: option.icon)
          .resizable()
          .frame(width: Metric.activityIconSize, height: Metric.activityIconSize)
        Text(option.title)
          .festiCoreFont(.baseTitle2Bold)
          .lineLimit(1)
      }
    }
  }
}

// MARK: - 체이닝 설정

public extension FCBearerChoiceSheet {
  /// 제목·설명을 바꾼 사본을 돌려준다.
  func texts(
    title: String,
    message: String
  ) -> Self {
    var copy = self
    copy.title = title
    copy.message = message
    return copy
  }
}

private extension FCBearerChoiceSheet {
  enum Metric {
    static let zoneHeight: CGFloat = 64
    static let activityHeight: CGFloat = 120
    static let zoneIconSize: CGFloat = 16
    static let activityIconSize: CGFloat = 24
  }
}

#Preview {
  ScrollView {
    VStack(spacing: FestiCoreSpacing.paddingP24) {
      FCBearerChoiceSheet(
        .zone,
        options: ["리벳 스테이지 앞 왼쪽", "리벳 스테이지 중앙", "원더 스테이지 앞", "슬램 존"].map {
          FCBearerChoiceSheet.Option(
            id: $0,
            title: $0,
            icon: .locationDot16
          )
        },
        selectedID: "리벳 스테이지 앞 왼쪽",
        onSelect: { _ in }
      )
      FCBearerChoiceSheet(
        .activity,
        options: [
          FCBearerChoiceSheet.Option(
            id: "slam",
            title: "슬램",
            icon: .users24
          ),
          FCBearerChoiceSheet.Option(
            id: "singalong",
            title: "떼창",
            icon: .music24
          ),
          FCBearerChoiceSheet.Option(
            id: "train",
            title: "기차놀이",
            icon: .route24
          ),
          FCBearerChoiceSheet.Option(
            id: "calm",
            title: "차분",
            icon: .user24
          ),
        ],
        selectedID: "slam",
        onSelect: { _ in }
      )
    }
  }
  .background(FestiCoreSemanticColor.backgroundElevated.color)
}
