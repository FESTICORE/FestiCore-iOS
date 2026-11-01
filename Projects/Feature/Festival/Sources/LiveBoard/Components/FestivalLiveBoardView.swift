import FestiCoreDesignKit
import FestiCoreUtility
import SwiftUI

/// `지금 / 다음 무대` 섹션. 무대 카드 한 장 안에 무대별 행을 구분선으로 나눠 그린다.
struct FestivalLiveBoardView: View {
  let rows: [FestivalLiveBoardPresentation.StageRow]
  let updated: String?
  let source: String?

  var body: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
      FCSectionHeader("지금 / 다음 무대")
        .action(updated)
      if rows.isEmpty {
        Text("현재 진행 중이거나 예정된 공연 정보가 없습니다.")
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(FestiCoreSpacing.paddingP20)
          .background(FestiCoreSemanticColor.backgroundElevated.color,
                      in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      } else {
        VStack(spacing: .zero) {
          ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            if index > 0 {
              FestiCoreSemanticColor.lineNormal.color
                .frame(height: 1)
            }
            stageRow(row)
          }
        }
        .background(FestiCoreSemanticColor.backgroundElevated.color)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
      }
      if let source {
        FCSourceLine(source)
      }
    }
  }
}

private extension FestivalLiveBoardView {
  func stageRow(_ row: FestivalLiveBoardPresentation.StageRow) -> some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        Text(row.name)
          .festiCoreFont(.baseFootnoteBold)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .frame(maxWidth: .infinity, alignment: .leading)
        if row.isMine {
          FCTag("내 일정")
            .tone(.lime)
        }
      }
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        if let now = row.now {
          slot(now, kind: .now)
        }
        if row.now != nil, row.next != nil {
          Image(asset: .chevronRight16)
            .resizable()
            .frame(width: 16, height: 16)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
            .accessibilityHidden(true)
        }
        if let next = row.next {
          slot(next, kind: .next)
        }
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(row.isMine ? FestiCoreSemanticColor.accentBackgroundLime.color : .clear)
    .accessibilityElement(children: .combine)
  }

  func slot(_ slot: FestivalLiveBoardPresentation.StageRow.Slot, kind: FCLiveBadge.Kind) -> some View {
    HStack(alignment: .top, spacing: FestiCoreSpacing.paddingP8) {
      FCLiveBadge(kind)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP4) {
        Text(slot.artist)
          .festiCoreFont(kind == .now ? .baseBodyBold : .baseCalloutMedium)
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        Text(slot.time)
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      }
      .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
