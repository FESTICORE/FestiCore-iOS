//
//  PackDetailView.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import SwiftUI

/// Figma Pack 팩 상세 A~F
@ViewAction(for: PackDetailFeature.self)
public struct PackDetailView: View {
  @Bindable public var store: StoreOf<PackDetailFeature>

  public init(store: StoreOf<PackDetailFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      FCTopBar(.back, title: store.title)
        .onBack { send(.backTapped) }
      FCTab(selection: tabSelection, items: ["가는 길", "준비물", "팩 관리"])
      content
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .toolbar(.hidden, for: .navigationBar)
    .onAppear { send(.onAppear) }
    .fcAlert($store.scope(state: \.destination?.alert, action: \.destination.alert), dismissesOnDimTap: true)
  }
}

extension PackDetailView {
  /// 탭 바 칸 번호와 본문 페이지 번호가 함께 쓰는 선택 값. 탭을 누르든 스와이프하든 같은 액션을 보낸다.
  private var tabSelection: Binding<Int> {
    return Binding(
      get: { store.tab.rawValue },
      set: { send(.tabSelected(Self.tab(at: $0))) }
    )
  }

  /// 탭 바 칸·본문 페이지 번호를 탭으로 바꾼다. 범위를 벗어나면 가는 길로 둔다.
  static func tab(at index: Int) -> PackDetailFeature.Tab {
    return PackDetailFeature.Tab(rawValue: index) ?? .directions
  }

  @ViewBuilder
  private var content: some View {
    switch store.load {
    case .loading:
      loadingContent
    case .failed:
      messageContent("팩을 불러오지 못했어요", actionTitle: "다시 시도") { send(.retryTapped) }
    case .missing:
      messageContent("기기에 받은 팩이 없어요", actionTitle: nil, action: nil)
    case .loaded:
      if let detail = store.detail {
        // 탭 바와 같은 선택 값을 써서 본문을 좌우로 넘기면 탭도 함께 바뀐다.
        TabView(selection: tabSelection) {
          ForEach(
            PackDetailFeature.Tab.allCases,
            id: \.self
          ) { tab in
            page(
              tab,
              detail: detail
            )
            .tag(tab.rawValue)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
      }
    }
  }

  /// 탭 한 장. 탭마다 스크롤 위치를 따로 둔다.
  private func page(
    _ tab: PackDetailFeature.Tab,
    detail: FestivalPackDetail
  ) -> some View {
    return ScrollView {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP16
      ) {
        switch tab {
        case .directions: directions(detail)
        case .checklist: checklist(detail)
        case .manage: manage(detail.pack)
        }
      }
      .padding(
        .horizontal,
        FestiCoreSpacing.paddingP16
      )
      .padding(
        .top,
        FestiCoreSpacing.paddingP16
      )
    }
    .scrollIndicators(.hidden)
    // 탭바 없이 열리므로 마지막 카드가 화면 아래(홈 인디케이터)에서 20pt 떨어져 멈춘다.
    .fcScrollBottomInset()
  }

  private var loadingContent: some View {
    VStack(spacing: FestiCoreSpacing.paddingP16) {
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: 96)
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: 160)
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: 120)
    }
    .padding(FestiCoreSpacing.paddingP16)
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private func messageContent(
    _ message: String,
    actionTitle: String?,
    action: (() -> Void)?
  ) -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      Text(message)
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      if let actionTitle, let action {
        FCButton(actionTitle, action: action)
          .style(.secondary)
          .size(.medium)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - A. 가는 길

  @ViewBuilder
  private func directions(_ detail: FestivalPackDetail) -> some View {
    let directions = detail.directions
    if directions.isEmpty {
      card {
        Text("가는 길 정보가 아직 없어요")
          .festiCoreFont(.baseBodyRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
          .frame(maxWidth: .infinity, minHeight: 56)
      }
    } else {
      if directions.lastShuttleAt != nil || directions.lastTrainAt != nil {
        FCLastRideCard(
          shuttle: Self.timeText(directions.lastShuttleAt),
          train: Self.timeText(directions.lastTrainAt)
        )
      }
      if let shuttle = directions.shuttle {
        directionSection("셔틀", section: shuttle) {
          ForEach(shuttle.links, id: \.url) { link in
            linkButton(link.label, url: link.url)
          }
        }
      }
      if let transit = directions.transit {
        directionSection("대중교통", section: transit) {
          mapButtons(directions)
        }
      } else if directions.naverMapURL != nil || directions.kakaoMapURL != nil {
        card { mapButtons(directions) }
      }
      if let parking = directions.parking {
        directionSection("주차", section: parking) { EmptyView() }
      }
      if let memo = directions.memo {
        card {
          VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
            cardTitle("팀 추천 메모")
            cardBody(memo)
          }
        }
      }
      if let source = sourceText(directions.source ?? detail.source) {
        // 시안 Pack A의 출처 줄은 본문 폭(361) 그대로 띠를 깐다.
        FCSourceLine(source)
      }
    }
  }

  private func directionSection(
    _ title: String,
    section: FestivalPackDetail.Section,
    @ViewBuilder actions: () -> some View
  ) -> some View {
    card {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
        VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
          cardTitle(title)
          if let body = sectionBody(section) {
            cardBody(body)
          }
        }
        actions()
      }
    }
  }

  @ViewBuilder
  private func mapButtons(_ directions: FestivalPackDetail.Directions) -> some View {
    if directions.naverMapURL != nil || directions.kakaoMapURL != nil {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        if let url = directions.naverMapURL {
          linkButton("네이버 지도", url: url)
        }
        if let url = directions.kakaoMapURL {
          linkButton("카카오맵", url: url)
        }
      }
    }
  }

  private func linkButton(_ title: String, url: URL) -> some View {
    FCButton(title) { send(.linkTapped(url)) }
      .style(.secondary)
      .size(.medium)
      .isFullWidth(true)
  }

  // MARK: - B·C. 준비물

  @ViewBuilder
  private func checklist(_ detail: FestivalPackDetail) -> some View {
    let rows = store.state.checklistRows
    card {
      FCChecklistProgress(checked: store.state.checkedCount, total: rows.count)
    }
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      FCSectionHeader("챙길 것")
        .action(store.isEditingChecklist ? "완료" : "편집") {
          send(store.isEditingChecklist ? .editDoneTapped : .editTapped)
        }
      VStack(spacing: .zero) {
        ForEach(rows) { row in
          if store.isEditingChecklist {
            FCChecklistEditRow(row.label)
              .onDelete(row.isRequired ? nil : { send(.itemRemoved(row.id)) })
          } else {
            FCChecklistRow(row.label, isChecked: row.isChecked) {
              send(.itemToggled(row.id))
            }
            .isRequired(row.isRequired)
          }
          if row.id != rows.last?.id {
            divider
          }
        }
        if store.isEditingChecklist || rows.isEmpty {
          if !rows.isEmpty { divider }
          FCAddItemRow(text: $store.newItemText) { send(.addItemTapped) }
        } else {
          divider
          addItemPrompt
        }
      }
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
      if store.isEditingChecklist && rows.contains(where: \.isRequired) {
        footnote("필수 항목은 운영팀이 정한 거라 지울 수 없어요.")
      }
    }
    if !detail.rules.isEmpty {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        FCSectionHeader("반입 금지")
        card {
          VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP12) {
            PackRuleTags(tags: detail.rules)
            if let source = sourceText(detail.source) {
              // 카드 안에서는 출처 줄의 띠와 안쪽 여백을 빼고 카드 여백을 쓴다.
              FCSourceLine(source)
                .inset(false)
            }
          }
        }
      }
    }
  }

  private var addItemPrompt: some View {
    Button { send(.editTapped) } label: {
      HStack(spacing: FestiCoreSpacing.paddingP8) {
        Image(systemName: "plus")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          .accessibilityHidden(true)
        Text("내 항목 추가")
          .festiCoreFont(.baseCalloutRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        Spacer()
      }
      .padding(.horizontal, FestiCoreSpacing.paddingP16)
      .frame(height: 56)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - D·E. 팩 관리

  @ViewBuilder
  private func manage(_ pack: FestivalReceivedPack) -> some View {
    card {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        packThumbnail(pack)
        VStack(alignment: .leading, spacing: FestiCoreSpacing.marginM2) {
          Text(pack.name)
            .festiCoreFont(.baseCalloutMedium)
            .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
          Text(packStatus(pack))
            .festiCoreFont(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        if pack.hasUpdate {
          FCTag("업데이트").tone(.warning)
        }
      }
    }
    if pack.hasUpdate {
      VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
        FCButton(updateTitle(pack)) { send(.updateTapped) }
          .style(.primary)
          .isFullWidth(true)
          .isEnabled(!store.isUpdating && !store.isDeleting)
        if let summary = changeSummary {
          footnote("바뀐 내용: \(summary)")
        }
      }
    }
    VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
      FCSectionHeader("팩 정보")
      VStack(spacing: .zero) {
        infoRow("버전", value: versionText(pack))
        divider
        infoRow("마지막 확인", value: pack.checkedAt.map(dateText) ?? "-")
        divider
        infoRow("용량", value: sizeText(pack.sizeBytes))
        divider
        FCListRow("와이파이에서 자동으로 받기", isOn: autoDownloadBinding)
      }
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
    }
    if !pack.hasUpdate {
      FCButton("지금 업데이트 확인") { send(.checkUpdateTapped) }
        .style(.secondary)
        .isFullWidth(true)
        .isEnabled(!store.isUpdating && !store.isDeleting)
    }
    if let message = store.manageMessage {
      footnote(message)
        .accessibilityAddTraits(.updatesFrequently)
    }
    Button { send(.deleteTapped) } label: {
      Text("팩 삭제")
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.statusNegative.color)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, FestiCoreSpacing.paddingP16)
        .background(
          FestiCoreSemanticColor.backgroundElevated.color,
          in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
        )
    }
    .buttonStyle(.plain)
    .disabled(store.isDeleting || store.isUpdating)
    footnote("팩을 지워도 내 일정과 체크한 준비물은 남아 있어요.")
  }

  private var autoDownloadBinding: Binding<Bool> {
    Binding(
      get: { store.autoDownloadOnWiFi },
      set: { send(.autoDownloadToggled($0)) }
    )
  }

  @ViewBuilder
  private func packThumbnail(_ pack: FestivalReceivedPack) -> some View {
    if let url = pack.thumbnailURL {
      FCRemoteImage(url: url)
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r8))
        .accessibilityHidden(true)
    } else {
      FCThumbnail(nil).size(44)
    }
  }

  private func infoRow(_ title: String, value: String) -> some View {
    HStack {
      Text(title)
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      Spacer()
      Text(value)
        .festiCoreFont(.baseBodyRegular)
        .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
        .monospacedDigit()
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .frame(minHeight: 56)
    .accessibilityElement(children: .combine)
  }

  // MARK: - 공통

  private func card(@ViewBuilder content: () -> some View) -> some View {
    content()
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(FestiCoreSpacing.paddingP16)
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
  }

  private func cardTitle(_ title: String) -> some View {
    Text(title)
      .festiCoreFont(.baseBodyBold)
      .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      .accessibilityAddTraits(.isHeader)
  }

  private func cardBody(_ text: String) -> some View {
    Text(text)
      .festiCoreFont(.baseCalloutRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func footnote(_ text: String) -> some View {
    Text(text)
      .festiCoreFont(.baseFootnoteRegular)
      .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, FestiCoreSpacing.paddingP4)
  }

  private var divider: some View {
    FestiCoreSemanticColor.lineNormal.color
      .frame(height: 1)
      .padding(.leading, FestiCoreSpacing.paddingP16)
  }

  // MARK: - 문구

  private func sectionBody(_ section: FestivalPackDetail.Section) -> String? {
    var lines: [String] = []
    if let station = section.stationName {
      lines.append(section.walkMinutes.map { "가장 가까운 역은 \(station)이에요. 걸어서 \($0)분 정도 걸려요." }
        ?? "가장 가까운 역은 \(station)이에요.")
    }
    if let body = section.body { lines.append(body) }
    return lines.isEmpty ? nil : lines.joined(separator: " ")
  }

  /// ISO 시각이면 축제 시간대(서울)의 24시간 HH:mm으로, 아니면 서버 값 그대로 보인다.
  /// 기기 설정의 12시간제·시간대를 따르면 22:20이 10:20으로 보인다.
  static func timeText(_ value: String?) -> String {
    guard let value else { return "-" }
    return value.isoDate.map { $0.formatted(.time) } ?? value
  }

  private func sourceText(_ source: FestivalPackDetail.Source?) -> String? {
    guard let source else { return nil }
    guard let verifiedAt = source.verifiedAt else { return "출처: \(source.name)" }
    return "출처: \(source.name) · 확인 \(dateText(verifiedAt))"
  }

  /// Figma처럼 "10/16 14:00"으로 쓴다.
  private func dateText(_ date: Date) -> String {
    return date.formatted(.monthDayTime)
  }

  private func packStatus(_ pack: FestivalReceivedPack) -> String {
    if pack.hasUpdate, let latest = pack.latestPackVersion {
      return "새 버전이 있어요 · v\(latest)"
    }
    guard let checkedAt = pack.checkedAt else { return "최신 버전 · v\(pack.packVersion)" }
    return "최신 버전 · \(dateText(checkedAt)) 확인"
  }

  private func versionText(_ pack: FestivalReceivedPack) -> String {
    guard pack.hasUpdate, let latest = pack.latestPackVersion else { return "v\(pack.packVersion)" }
    return "v\(pack.packVersion) (새 버전 v\(latest))"
  }

  private func updateTitle(_ pack: FestivalReceivedPack) -> String {
    if store.isUpdating { return "받는 중…" }
    guard let size = store.changes?.sizeBytes else { return "업데이트 받기" }
    return "업데이트 받기 · \(sizeText(size))"
  }

  private var changeSummary: String? {
    guard let changes = store.changes else { return nil }
    var parts: [String] = []
    if let count = changes.changedSets, count > 0 { parts.append("시간표 \(count)개 변경") }
    if let shuttle = changes.lastShuttleAt {
      parts.append("셔틀 막차 \(Self.timeText(shuttle.before)) → \(Self.timeText(shuttle.after))")
    }
    if let train = changes.lastTrainAt {
      parts.append("막차 \(Self.timeText(train.before)) → \(Self.timeText(train.after))")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private func sizeText(_ bytes: Int) -> String {
    let megabytes = Double(bytes) / 1_048_576
    return megabytes >= 0.1 ? String(format: "%.1fMB", megabytes) : "\(max(1, bytes / 1024))KB"
  }
}

#Preview {
  PackDetailView(store: Store(initialState: PackDetailFeature.State(festivalID: "fst_preview", title: "원더리벳 2026")) {
    PackDetailFeature()
  })
}
