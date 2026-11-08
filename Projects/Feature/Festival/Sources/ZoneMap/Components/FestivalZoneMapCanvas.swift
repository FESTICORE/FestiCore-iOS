//
//  FestivalZoneMapCanvas.swift
//  Festival
//
//  Created by FestiCore on 11/8/26.
//

import FestiCoreDesignKit
import FestivalDomainInterface
import SwiftUI

/// Figma S06 지도 본문. 존 영역(0~1 비율)을 지도 너비에 맞춰 그리고 영역 안에 마커를 놓는다.
struct FestivalZoneMapCanvas: View {
  let map: FestivalZoneMap
  let model: FestivalZoneMapModel
  let selectedZoneID: String?
  let width: CGFloat
  let onZoneTap: (String) -> Void
  let onBackgroundTap: () -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture(perform: onBackgroundTap)
      ForEach(map.stageHeaders) { header in
        FestivalZoneMapStageHeader(header: header)
          .frame(width: header.width * width)
          .offset(
            x: header.x * width,
            y: header.y * height
          )
      }
      ForEach(map.zones) { zone in
        if let area = zone.area {
          FestivalZoneMapArea(
            zone: zone,
            markers: model.markers[zone.id] ?? [],
            isSelected: zone.id == selectedZoneID,
            isCompact: area.height * height < FestivalZoneMapArea.Metric.compactHeight
          ) {
            onZoneTap(zone.id)
          }
          .frame(
            width: area.width * width,
            height: area.height * height
          )
          .offset(
            x: area.x * width,
            y: area.y * height
          )
          // 스크롤 기준은 지도 위쪽부터 존 아래 여백까지 덮는다(.offset은 배치 위치를 바꾸지 않는다).
          Color.clear
            .frame(
              width: 1,
              height: (area.y + area.height) * height + Metric.revealMargin
            )
            .id(Self.revealID(zone.id))
        }
      }
    }
    .frame(
      width: width,
      height: height,
      alignment: .topLeading
    )
  }
}

extension FestivalZoneMapCanvas {
  /// 고른 존을 보이게 할 때 쓰는 스크롤 기준 ID
  static func revealID(_ zoneID: String) -> String {
    return "reveal-\(zoneID)"
  }
}

private extension FestivalZoneMapCanvas {
  var height: CGFloat {
    return width / CGFloat(map.aspect ?? 1)
  }

  enum Metric {
    /// Figma S06 E: 고른 존 아래에 카드 바깥 여백(16)과 합쳐 50pt를 남긴다.
    static let revealMargin: CGFloat = 34
  }
}

/// 무대 이름과 지금 공연 중인 아티스트 줄
struct FestivalZoneMapStageHeader: View {
  let header: FestivalZoneMap.StageHeader

  var body: some View {
    HStack(spacing: FestiCoreSpacing.marginM8) {
      // Figma 무대 이름(10pt)은 토큰보다 작아서 좁을 때만 줄여 맞춘다.
      Text(header.name.uppercased())
        .festiCoreFont(.baseCaption2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .lineLimit(1)
        .minimumScaleFactor(Metric.nameMinimumScale)
        .frame(
          maxWidth: .infinity,
          alignment: .leading
        )
      // 지금 공연 아티스트는 자르지 않고, 좁으면 무대 이름을 줄인다.
      if let nowPlaying = header.nowPlaying {
        Text("지금 \(nowPlaying)")
          .festiCoreFont(.baseCaption2Medium)
          .foregroundStyle(FestiCoreSemanticColor.inverseLabel.color)
          .lineLimit(1)
          .fixedSize()
          .padding(
            .horizontal,
            Metric.tagHorizontalPadding
          )
          .frame(height: Metric.tagHeight)
          .background(
            FestiCoreSemanticColor.inverseBackground.color,
            in: RoundedRectangle(cornerRadius: FestiCoreRadius.r4)
          )
      }
    }
    .padding(
      .leading,
      FestiCoreSpacing.paddingP12
    )
    .padding(
      .trailing,
      Metric.trailingPadding
    )
    .frame(height: Metric.height)
    .background(
      FestiCoreSemanticColor.fillNormal.color,
      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r8)
    )
  }
}

private extension FestivalZoneMapStageHeader {
  enum Metric {
    static let height: CGFloat = 34
    static let nameMinimumScale: CGFloat = 0.85
    static let tagHeight: CGFloat = 18
    static let tagHorizontalPadding: CGFloat = 6
    static let trailingPadding: CGFloat = 10
  }
}

/// 존 영역 하나. 이름표·표지·마커를 그리고 누르면 존 카드를 연다.
struct FestivalZoneMapArea: View {
  let zone: FestivalZoneMap.Zone
  let markers: [FestivalZoneMapModel.Marker]
  let isSelected: Bool
  /// 이름표 아래에 마커 줄을 둘 높이가 없는 영역(Figma 정문). 마커를 이름표 줄 끝에 둔다.
  let isCompact: Bool
  let action: () -> Void

  var body: some View {
    // 이름표·마커가 영역보다 커도 영역 크기는 지도 좌표를 따른다(넘친 내용은 아래로 그린다).
    VStack(
      alignment: .leading,
      spacing: .zero
    ) {
      header
      if !isCompact {
        markerRow
      }
    }
    .frame(
      minWidth: .zero,
      maxWidth: .infinity,
      minHeight: .zero,
      maxHeight: .infinity,
      alignment: .topLeading
    )
    .background {
      shape
        .fill(isSelected ? FestiCoreSemanticColor.accentBackgroundLime.color : FestiCoreSemanticColor.backgroundElevated.color)
      if isSelected {
        shape.strokeBorder(
          FestiCoreSemanticColor.staticLime.color,
          lineWidth: Metric.selectedBorder
        )
      }
    }
    .contentShape(shape)
    .onTapGesture(perform: action)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

private extension FestivalZoneMapArea {
  var shape: RoundedRectangle {
    return RoundedRectangle(cornerRadius: Metric.cornerRadius)
  }

  var header: some View {
    return HStack(
      alignment: .top,
      spacing: FestiCoreSpacing.marginM4
    ) {
      nameLabel
      if isCompact && !markers.isEmpty {
        landmarkBadge
          .padding(
            .leading,
            FestiCoreSpacing.marginM4
          )
        Spacer(minLength: .zero)
        markerStack
          .padding(
            .trailing,
            Metric.markerInset - Metric.headerInset
          )
      } else {
        Spacer(minLength: .zero)
        landmarkBadge
      }
    }
    .padding(Metric.headerInset)
  }

  var nameLabel: some View {
    // Figma 이름표는 좁은 영역 밖으로 넘쳐도 이름을 자르지 않는다.
    return Text(zone.name)
      .festiCoreFont(.baseFootnoteBold)
      .festiCoreLineBox(.baseFootnoteBold)
      .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
      .lineLimit(1)
      .fixedSize()
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP8
      )
      .padding(
        .vertical,
        Metric.labelVerticalPadding
      )
      .background(
        isSelected ? FestiCoreSemanticColor.staticLime.color : FestiCoreSemanticColor.fillNormal.color,
        in: RoundedRectangle(cornerRadius: Metric.labelRadius)
      )
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: Metric.labelRadius)
            .strokeBorder(
              FestiCoreSemanticColor.staticInk.color,
              lineWidth: Metric.labelBorder
            )
        }
      }
  }

  @ViewBuilder
  var landmarkBadge: some View {
    if let landmark = zone.landmark {
      Text(landmark)
        .festiCoreFont(.baseCaption2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        .lineLimit(1)
        .padding(
          .horizontal,
          FestiCoreSpacing.paddingP8
        )
        .frame(height: Metric.landmarkHeight)
        .overlay {
          Capsule().strokeBorder(
            FestiCoreSemanticColor.lineStrong.color,
            lineWidth: Metric.labelBorder
          )
        }
    }
  }

  var markerStack: some View {
    return HStack(
      alignment: .top,
      spacing: Metric.markerSpacing
    ) {
      ForEach(markers) { marker in
        FestivalZoneMapMarker(marker: marker)
      }
    }
  }

  @ViewBuilder
  var markerRow: some View {
    GeometryReader { proxy in
      let available = proxy.size.width - Metric.markerInset * 2
      if FestivalZoneMapMarker.totalWidth(markers) <= available {
        markerStack
          .padding(
            .leading,
            Metric.markerInset
          )
      } else {
        FestivalZoneMapCluster(count: markers.count)
          .frame(maxWidth: .infinity)
      }
    }
  }

  enum Metric {
    static let cornerRadius: CGFloat = 10
    static let selectedBorder: CGFloat = 1.5
    static let labelRadius: CGFloat = 6
    static let labelBorder: CGFloat = 1
    static let labelVerticalPadding: CGFloat = 3
    static let landmarkHeight: CGFloat = 20
    static let headerInset: CGFloat = 4
    static let markerInset: CGFloat = 12
    static let markerSpacing: CGFloat = 12
    /// 이름표 줄(32) + 마커 원(40)보다 낮으면 마커를 이름표 줄에 둔다.
    static let compactHeight: CGFloat = 72
  }
}

/// 존 안 마커. 팔로우 깃발·크루는 이름표를, 다른 깃발은 원만 그린다.
struct FestivalZoneMapMarker: View {
  let marker: FestivalZoneMapModel.Marker

  var body: some View {
    VStack(spacing: Metric.labelSpacing) {
      circle
        .frame(
          width: Metric.box,
          height: Metric.box
        )
      if hasLabel {
        Text(marker.name)
          .festiCoreFont(.baseCaption2Bold)
          .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
          .lineLimit(1)
          .padding(
            .horizontal,
            Metric.labelHorizontalPadding
          )
          .frame(height: Metric.labelHeight)
          .background(
            FestiCoreSemanticColor.staticWhite.color,
            in: RoundedRectangle(cornerRadius: FestiCoreRadius.r4)
          )
          .shadow(
            color: FestiCoreSemanticColor.staticalphaBlack20.color,
            radius: Metric.labelShadowRadius,
            y: Metric.shadowY
          )
      }
    }
    .opacity(marker.isStale ? Metric.staleOpacity : 1)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(marker.name)
  }

  /// 마커를 한 줄에 놓을 때 필요한 너비. 넘치면 `+N` 묶음으로 바꾼다.
  static func totalWidth(_ markers: [FestivalZoneMapModel.Marker]) -> CGFloat {
    guard !markers.isEmpty else { return 0 }
    let widths = markers.map { marker -> CGFloat in
      switch marker.kind {
      case .followedFlag: return Metric.labeledWidth
      case .crew: return Metric.box
      case .otherFlag: return Metric.box
      }
    }
    return widths.reduce(
      0,
      +
    ) + CGFloat(markers.count - 1) * FestivalZoneMapArea.Metric.markerSpacing
  }
}

private extension FestivalZoneMapMarker {
  var hasLabel: Bool {
    switch marker.kind {
    case .followedFlag, .crew: return true
    case .otherFlag: return false
    }
  }

  @ViewBuilder
  var circle: some View {
    switch marker.kind {
    case .followedFlag:
      bubble(
        size: Metric.followedSize,
        fill: FestiCoreSemanticColor.staticLime.color
      ) {
        Image(asset: .flag16)
          .resizable()
          .frame(
            width: Metric.followedIcon,
            height: Metric.followedIcon
          )
          .foregroundStyle(FestiCoreSemanticColor.staticInk.color)
      }
    case let .crew(badge):
      FCAvatar(badge.initial)
        .tint(badge.tint)
        .size(.small)
        .padding(Metric.border)
        .background(
          FestiCoreSemanticColor.staticWhite.color,
          in: Circle()
        )
        .overlay {
          Circle().strokeBorder(
            FestiCoreSemanticColor.staticWhite.color,
            lineWidth: Metric.border
          )
        }
        .shadow(
          color: FestiCoreSemanticColor.staticalphaBlack20.color,
          radius: Metric.shadowRadius,
          y: Metric.shadowY
        )
    case .otherFlag:
      bubble(
        size: Metric.otherSize,
        fill: FestiCoreSemanticColor.labelAssistive.color
      ) {
        Image(asset: .flag16)
          .resizable()
          .frame(
            width: Metric.otherIcon,
            height: Metric.otherIcon
          )
          .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
      }
    }
  }

  func bubble(
    size: CGFloat,
    fill: Color,
    @ViewBuilder content: () -> some View
  ) -> some View {
    return content()
      .frame(
        width: size,
        height: size
      )
      .background(
        fill,
        in: Circle()
      )
      .overlay {
        Circle().strokeBorder(
          FestiCoreSemanticColor.staticWhite.color,
          lineWidth: Metric.border
        )
      }
      .shadow(
        color: FestiCoreSemanticColor.staticalphaBlack20.color,
        radius: Metric.shadowRadius,
        y: Metric.shadowY
      )
  }

  enum Metric {
    static let box: CGFloat = 40
    static let labeledWidth: CGFloat = 52
    static let followedSize: CGFloat = 40
    static let followedIcon: CGFloat = 16
    static let otherSize: CGFloat = 28
    static let otherIcon: CGFloat = 12
    static let border: CGFloat = 2
    static let labelSpacing: CGFloat = 6
    static let labelHeight: CGFloat = 22
    static let labelHorizontalPadding: CGFloat = 6
    static let labelShadowRadius: CGFloat = 2
    static let shadowRadius: CGFloat = 4
    static let shadowY: CGFloat = 2
    static let staleOpacity: Double = 0.4
  }
}

/// 영역에 다 놓을 수 없는 마커 묶음(Figma S06 C `+3`)
struct FestivalZoneMapCluster: View {
  let count: Int

  var body: some View {
    Text("+\(count)")
      .festiCoreFont(.baseCaption1Bold)
      .foregroundStyle(FestiCoreSemanticColor.staticWhite.color)
      .frame(
        width: Metric.size,
        height: Metric.size
      )
      .background(
        FestiCoreSemanticColor.staticInk.color,
        in: Circle()
      )
      .overlay {
        Circle().strokeBorder(
          FestiCoreSemanticColor.staticWhite.color,
          lineWidth: Metric.border
        )
      }
      .shadow(
        color: FestiCoreSemanticColor.staticalphaBlack20.color,
        radius: Metric.shadowRadius,
        y: Metric.shadowY
      )
      .frame(height: Metric.box)
      .accessibilityLabel("\(count)개")
  }
}

private extension FestivalZoneMapCluster {
  enum Metric {
    static let size: CGFloat = 32
    static let box: CGFloat = 40
    static let border: CGFloat = 2
    static let shadowRadius: CGFloat = 4
    static let shadowY: CGFloat = 2
  }
}

/// 지도 마커 범례. 상황에 따라 항목을 끈다.
struct FestivalZoneMapLegend: View {
  let showsFollowed: Bool
  let showsCrew: Bool
  let showsOther: Bool

  var body: some View {
    HStack(spacing: FestiCoreSpacing.marginM12) {
      if showsFollowed {
        item(
          "팔로우 깃발",
          color: FestiCoreSemanticColor.staticLime.color,
          bordered: true
        )
      }
      if showsCrew {
        item(
          "크루",
          color: FestiCoreSemanticColor.accentPointBlue.color,
          bordered: false
        )
      }
      if showsOther {
        item(
          "다른 깃발",
          color: FestiCoreSemanticColor.labelAssistive.color,
          bordered: false
        )
      }
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP12
    )
    .frame(height: Metric.height)
    .background(
      FestiCoreSemanticColor.backgroundElevated.color,
      in: Capsule()
    )
    .shadow(
      color: FestiCoreSemanticColor.staticalphaBlack20.color,
      radius: Metric.shadowRadius,
      y: Metric.shadowY
    )
  }
}

private extension FestivalZoneMapLegend {
  func item(
    _ title: String,
    color: Color,
    bordered: Bool
  ) -> some View {
    return HStack(spacing: FestiCoreSpacing.marginM4) {
      Circle()
        .fill(color)
        .overlay {
          if bordered {
            Circle().strokeBorder(
              FestiCoreSemanticColor.staticInk.color,
              lineWidth: 1
            )
          }
        }
        .frame(
          width: Metric.dot,
          height: Metric.dot
        )
      Text(title)
        .festiCoreFont(.baseCaption1Medium)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  enum Metric {
    static let height: CGFloat = 28
    static let dot: CGFloat = 8
    static let shadowRadius: CGFloat = 4
    static let shadowY: CGFloat = 2
  }
}
