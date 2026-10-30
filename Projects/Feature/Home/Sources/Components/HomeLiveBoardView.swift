import FestiCoreDesignKit
import SwiftUI

struct HomeLiveBoardView: View {
  let pack: FestivalPackDocument

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { timeline in
      let stages = HomeLiveBoardSchedule.resolve(pack: pack, now: timeline.date)
      if !stages.isEmpty {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
          Text("무대 현황")
            .font(.title2.bold())
          ForEach(stages) { stage in
            VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
              Text(stage.name)
                .font(.headline)
                .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
              if let current = stage.current {
                performance(current, kind: .now)
                  .padding(FestiCoreSpacing.paddingP12)
                  .background(
                    FestiCoreSemanticColor.accentBackgroundLime.color,
                    in: RoundedRectangle(cornerRadius: FestiCoreRadius.r12)
                  )
              }
              if let next = stage.next {
                performance(next, kind: .next)
                  .padding(.horizontal, FestiCoreSpacing.paddingP12)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FestiCoreSpacing.paddingP16)
            .background(
              FestiCoreSemanticColor.backgroundElevated.color,
              in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
            )
          }
        }
      }
    }
  }

  private func performance(_ slot: HomeLiveBoardSchedule.Slot, kind: FCLiveBadge.Kind) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      FCLiveBadge(kind)
      Text(slot.artist)
        .font(.subheadline.bold())
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Spacer(minLength: 4)
      Text(HomeDateFormat.time(from: slot.startsAt))
        .font(.caption.monospacedDigit())
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
    .accessibilityElement(children: .combine)
  }
}
