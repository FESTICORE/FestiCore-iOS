import FestiCoreDesignKit
import FestiCoreUtility
import SwiftUI

struct FestivalLiveBoardView: View {
  let pack: FestivalPackDocument

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { timeline in
      let stages = FestivalLiveBoardSchedule.resolve(pack: pack, now: timeline.date)
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP16) {
        HStack {
          Text("지금 / 다음 무대")
            .festiCoreFont(.baseTitle3Bold)
          Spacer()
          if stages.contains(where: { $0.current != nil }) {
            FCLivePulse()
          }
        }
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)

        if stages.isEmpty {
          Text("현재 진행 중이거나 예정된 공연 정보가 없습니다.")
            .festiCoreFont(.baseSubheadlineRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FestiCoreSpacing.paddingP20)
            .background(FestiCoreSemanticColor.backgroundElevated.color,
                        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
        } else {
          ForEach(stages) { stage in
            VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
              Text(stage.name)
                .festiCoreFont(.baseHeadlineBold)
                .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
              if let current = stage.current {
                performance(current, kind: .now)
                  .padding(FestiCoreSpacing.paddingP12)
                  .background(FestiCoreSemanticColor.accentBackgroundLime.color,
                              in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
              }
              if let next = stage.next {
                performance(next, kind: .next)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FestiCoreSpacing.paddingP16)
            .background(FestiCoreSemanticColor.backgroundElevated.color,
                        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
          }
        }
      }
    }
  }

  private func performance(_ slot: FestivalLiveBoardSchedule.Slot, kind: FCLiveBadge.Kind) -> some View {
    HStack(spacing: FestiCoreSpacing.paddingP12) {
      FCLiveBadge(kind)
      Text(slot.artist)
        .festiCoreFont(.baseSubheadlineBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .lineLimit(1)
      Spacer(minLength: FestiCoreSpacing.paddingP4)
      Text(slot.startsAt.formatted(.time))
        .festiCoreFont(.baseCaption1Medium)
        .monospacedDigit()
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .accessibilityElement(children: .combine)
  }
}
