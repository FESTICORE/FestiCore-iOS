//
//  SchedulePickView.swift
//  Timetable
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI
import TimetableDomainInterface

/// Figma S15-1 준비 안내 · 내 일정 고르기
@ViewAction(for: SchedulePickFeature.self)
public struct SchedulePickView: View {
  public let store: StoreOf<SchedulePickFeature>

  public init(store: StoreOf<SchedulePickFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCStepHeader(step: 1)
        .onLater { send(.laterTapped) }
      ScrollView {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP20) {
          header
          FCSegmented(selection: dayBinding, items: store.days.map(\.title))
          setList
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      bottomBar
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
  }
}

private extension SchedulePickView {
  var header: some View {
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      Text("Step 1. 내 일정 고르기")
        .festiCoreFont(.baseCaption1Medium)
        .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      Text("보고 싶은 무대를 골라 주세요")
        .festiCoreFont(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
        .accessibilityAddTraits(.isHeader)
      Text("고른 무대는 시작 10분 전에 알려 드려요.\n나중에 타임테이블에서 언제든 바꿀 수 있어요.")
        .festiCoreFont(.baseSubheadlineRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
    }
  }

  var setList: some View {
    VStack(alignment: .trailing, spacing: FestiCoreSpacing.paddingP8) {
      Text("\(store.selectedSetIDs.count)개 선택")
        .festiCoreFont(.baseFootnoteBold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      if let day = store.selectedDay, !day.sets.isEmpty {
        VStack(spacing: .zero) {
          ForEach(Array(day.sets.sorted { $0.start < $1.start }.enumerated()), id: \.element.id) { index, set in
            if index > 0 {
              FestiCoreSemanticColor.lineNormal.color.frame(height: 1)
            }
            setRow(set, in: day)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r16))
        .overlay(
          RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
            .stroke(FestiCoreSemanticColor.lineNormal.color, lineWidth: 1)
        )
      } else {
        Text("이 날은 아직 공연 시간이 없어요.")
          .festiCoreFont(.baseSubheadlineRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, FestiCoreSpacing.paddingP24)
      }
      if let message = store.errorMessage {
        Text(message)
          .festiCoreFont(.baseCaption1Regular)
          .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  func setRow(_ set: TimetableSet, in day: TimetableDay) -> some View {
    FCSetSelectRow(
      artist: set.artist,
      stage: day.stages.first { $0.id == set.stageID }?.name ?? "무대 미정",
      start: Self.clock(set.start),
      end: Self.clock(set.end),
      isSelected: store.selectedSetIDs.contains(set.id)
    ) {
      send(.setTapped(set.id))
    }
    .overlapText(store.state.overlap(of: set).map { "\($0.artist)\(Self.withParticle($0.artist)) \($0.minutes)분 겹쳐요" })
  }

  var bottomBar: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      FCButton("건너뛰기") { send(.skipTapped) }
        .style(.ghost)
      FCButton(store.isSaving ? "저장하는 중" : "다음 · \(store.selectedSetIDs.count)개 선택") {
        send(.nextTapped)
      }
      .isEnabled(store.canSubmit)
      .isFullWidth(true)
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .padding(.top, FestiCoreSpacing.paddingP12)
    .padding(.bottom, FestiCoreSpacing.paddingP8)
    .overlay(alignment: .top) {
      FestiCoreSemanticColor.lineNormal.color.frame(height: 1)
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
  }

  var dayBinding: Binding<Int> {
    Binding(
      get: { store.selectedDayIndex },
      set: { send(.dayTapped($0)) }
    )
  }
}

/// 테스트가 확인하는 표시 문자열 규칙
extension SchedulePickView {
  /// 그날 0시부터의 분을 "HH:mm"으로 쓴다. 자정을 넘긴 시각은 다음 날 시각으로 쓴다.
  static func clock(_ minute: Int) -> String {
    String(format: "%02d:%02d", (minute / 60) % 24, minute % 60)
  }

  /// 받침이 없는 한글로 끝나면 "와", 그 밖에는 "과"를 붙인다.
  static func withParticle(_ word: String) -> String {
    guard let scalar = word.unicodeScalars.last, (0xAC00...0xD7A3).contains(scalar.value) else { return "과" }
    return (scalar.value - 0xAC00) % 28 == 0 ? "와" : "과"
  }
}

#Preview {
  SchedulePickView(store: Store(initialState: SchedulePickFeature.State(festivalID: "preview", days: [])) {
    SchedulePickFeature()
  })
}
