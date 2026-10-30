//
//  FCFestivalCard.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/30/26.
//

import SwiftUI

/// 페스티벌 목록 카드. 상태(D-N, 마감 임박, 예정, 종료) · 예매 여부 · 팩 상태를 표시한다.
public struct FCFestivalCard<Media: View>: View {
  public enum Status: Sendable {
    /// 진행 전, 태그에 D-N을 표시한다.
    case dDay(String)
    /// 마감 임박, 빨간 태그
    case closing(String)
    /// 티켓 오픈 예정
    case upcoming(String = "오픈 예정")
    /// 종료, 내용을 흐리게 보인다.
    case ended(String = "마감")
  }

  public enum Pack {
    /// 팩을 받을 수 없을 때의 안내 문구
    case unavailable(String)
    /// 받기 버튼
    case ready(title: String = "팩 받기", action: () -> Void)
    /// 받는 중, `progress`는 0...1
    case downloading(progress: Double, text: String)
    case received(String)
  }

  private var title: String
  private var meta: String
  private var status: Status
  private var media: Media
  private(set) var pack: Pack = .unavailable("예매한 페스티벌로 등록하면 팩을 받을 수 있어요")
  private(set) var isBooked = false
  private(set) var onBookmark: (() -> Void)?
  private(set) var ticketLinkTitle = "예매처 바로가기"
  private(set) var onTicketLink: (() -> Void)?

  public init(
    title: String,
    meta: String,
    status: Status,
    @ViewBuilder media: () -> Media
  ) {
    self.title = title
    self.meta = meta
    self.status = status
    self.media = media()
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
    VStack(spacing: 0) {
      media
        .frame(maxWidth: .infinity)
        .frame(height: Metric.mediaHeight)
        .clipped()
        .overlay(alignment: .topTrailing) { bookmarkButton }
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          Text(title)
            .festiCoreFont(.baseBodyBold)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(endedOpacity)
          statusTag
        }
        Text(meta)
          .festiCoreFont(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .lineLimit(1)
          .opacity(endedOpacity)
        packArea
          .opacity(endedOpacity)
      }
      .padding(FestiCoreSpacing.paddingP12)
      if let onTicketLink {
        ticketLink(action: onTicketLink)
          .opacity(endedOpacity)
      }
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .clipShape(shape)
    .overlay { shape.strokeBorder(FestiCoreSemanticColor.lineNormal.color, lineWidth: Metric.borderWidth) }
  }

}

private extension FCFestivalCard {
  @ViewBuilder
  var bookmarkButton: some View {
    if let onBookmark {
      Button(action: onBookmark) {
        Image(asset: .bookmark20)
          .resizable()
          .frame(width: Metric.bookmarkIconSize, height: Metric.bookmarkIconSize)
          .foregroundStyle(isBooked ? FestiCoreSemanticColor.staticLime.color : FestiCoreSemanticColor.staticalphaWhite60.color)
          .frame(width: Metric.bookmarkSize, height: Metric.bookmarkSize)
          .background(
            isBooked ? FestiCoreSemanticColor.staticalphaBlack40.color : FestiCoreSemanticColor.staticalphaBlack20.color,
            in: Circle()
          )
      }
      .buttonStyle(.plain)
      .padding(FestiCoreSpacing.paddingP8)
      .accessibilityLabel(isBooked ? "예매한 페스티벌 해제" : "예매한 페스티벌로 등록")
      .accessibilityAddTraits(isBooked ? .isSelected : [])
    }
  }

  private var statusTag: some View {
    let (label, background, foreground): (String, FestiCoreSemanticColor, FestiCoreSemanticColor) = {
      switch status {
      case let .dDay(label): return (label, .inverseBackground, .inverseLabel)
      case let .closing(label): return (label, .accentPointRed, .staticWhite)
      case let .upcoming(label): return (label, .fillStrong, .labelNormal)
      case let .ended(label): return (label, .labelAssistive, .staticWhite)
      }
    }()
    return Text(label)
      .festiCoreFont(.baseCaption2Bold)
      .foregroundStyle(foreground.color)
      .lineLimit(1)
      .padding(.vertical, FestiCoreSpacing.paddingP4)
      .padding(.horizontal, FestiCoreSpacing.marginM6)
      .background(background.color, in: RoundedRectangle(cornerRadius: FestiCoreRadius.r4))
  }

  @ViewBuilder
  private var packArea: some View {
    switch pack {
    case let .unavailable(helper):
      Text(helper)
        .festiCoreFont(.baseCaption1Regular)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
    case let .ready(title, action):
      FCButton(
        title,
        action: action
      )
      .style(.accent)
      .size(.medium)
      .isFullWidth(true)
    case let .downloading(progress, text):
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        Capsule()
          .fill(FestiCoreSemanticColor.fillStrong.color)
          .frame(height: Metric.progressHeight)
          .overlay(alignment: .leading) {
            GeometryReader { proxy in
              Capsule()
                .fill(FestiCoreSemanticColor.labelNormal.color)
                .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
          }
          .accessibilityHidden(true)
        Text(text)
          .festiCoreFont(.baseFootnoteBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      }
    case let .received(text):
      HStack(spacing: FestiCoreSpacing.paddingP4) {
        Image(asset: .circleCheck16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .foregroundStyle(FestiCoreSemanticColor.statusPositive.color)
          .accessibilityHidden(true)
        Text(text)
          .festiCoreFont(.baseFootnoteBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      }
    }
  }

  private func ticketLink(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Text(ticketLinkTitle)
          .festiCoreFont(.baseFootnoteMedium)
        Spacer()
        Image(asset: .arrowUpRightFromSquare16)
          .resizable()
          .frame(width: Metric.iconSize, height: Metric.iconSize)
          .accessibilityHidden(true)
      }
      .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      .padding(FestiCoreSpacing.paddingP12)
      .overlay(alignment: .top) {
        FestiCoreSemanticColor.lineNormal.color
          .frame(height: Metric.borderWidth)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var endedOpacity: Double {
    if case .ended = status {
      return FestiCoreState.disabledOpacity
    }
    return 1
  }
}

public extension FCFestivalCard where Media == FCFestivalImage {
  /// 기본 이미지 영역(`FCFestivalImage`)을 쓰는 카드.
  init(
    title: String,
    meta: String,
    status: Status,
    image: Image? = nil
  ) {
    self.init(
      title: title,
      meta: meta,
      status: status
    ) {
      FCFestivalImage(image)
    }
  }
}

// MARK: - 체이닝 설정

public extension FCFestivalCard {
  /// 팩 영역 상태를 바꾼 사본을 돌려준다.
  func pack(_ pack: Pack) -> Self {
    var copy = self
    copy.pack = pack
    return copy
  }

  /// 예매 여부와 북마크 동작을 바꾼 사본을 돌려준다. 동작이 없으면 북마크를 숨긴다.
  func booked(
    _ isBooked: Bool,
    onToggle: (() -> Void)?
  ) -> Self {
    var copy = self
    copy.isBooked = isBooked
    copy.onBookmark = onToggle
    return copy
  }

  /// 예매처 링크 동작을 바꾼 사본을 돌려준다. 동작이 없으면 링크 줄을 숨긴다.
  func ticketLink(
    _ title: String = "예매처 바로가기",
    action: (() -> Void)?
  ) -> Self {
    var copy = self
    copy.ticketLinkTitle = title
    copy.onTicketLink = action
    return copy
  }
}

private enum Metric {
  static let mediaHeight: CGFloat = 140
  static let bookmarkSize: CGFloat = 36
  static let bookmarkIconSize: CGFloat = 20
  static let iconSize: CGFloat = 16
  static let progressHeight: CGFloat = 6
  static let borderWidth: CGFloat = 1
}

#Preview {
  ScrollView {
    VStack(spacing: FestiCoreSpacing.paddingP24) {
      FCFestivalCard(
        title: "펜타포트 락 페스티벌 2026",
        meta: "인천 송도달빛축제공원 · 8/7(금) – 8/9(일)",
        status: .dDay("D-12")
      )
      .booked(false) {}
      .ticketLink {}
      FCFestivalCard(
        title: "펜타포트 락 페스티벌 2026",
        meta: "인천 송도달빛축제공원 · 8/7(금) – 8/9(일)",
        status: .closing("D-2")
      )
      .booked(true) {}
      .pack(.ready {})
      .ticketLink {}
      FCFestivalCard(
        title: "펜타포트 락 페스티벌 2026",
        meta: "인천 송도달빛축제공원 · 8/7(금) – 8/9(일)",
        status: .dDay("D-12")
      )
      .booked(true) {}
      .pack(.downloading(progress: 0.62, text: "팩 받는 중 · 62%"))
      .ticketLink {}
      FCFestivalCard(
        title: "펜타포트 락 페스티벌 2026",
        meta: "인천 송도달빛축제공원 · 8/7(금) – 8/9(일)",
        status: .ended()
      )
      .pack(.unavailable("종료된 페스티벌이라 팩을 받을 수 없어요"))
      .ticketLink {}
    }
    .padding(FestiCoreSpacing.paddingP24)
  }
  .background(FestiCoreSemanticColor.backgroundNormal.color)
}
