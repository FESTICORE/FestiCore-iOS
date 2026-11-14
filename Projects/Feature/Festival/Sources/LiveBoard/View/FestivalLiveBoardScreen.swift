import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import FestiCoreUtility
import FestivalDomainInterface
import SwiftUI
import UserNotificationDomainInterface

/// S01 라이브 보드. 시각은 서버 시각으로 보정하고 30초마다 다시 계산한다.
@ViewAction(for: FestivalFeature.self)
struct FestivalLiveBoardScreen: View {
  @Bindable var store: StoreOf<FestivalFeature>

  init(store: StoreOf<FestivalFeature>) {
    self.store = store
  }

  var body: some View {
    return Group {
      if let festival = store.selectedFestival {
        liveBoardContent(festival: festival)
      }
    }
    .background(FestiCoreSemanticColor.backgroundNormal.color)
    .toolbar(
      .hidden,
      for: .navigationBar
    )
    .overlay(alignment: .leading) {
      Color.clear
        .contentShape(Rectangle())
        .frame(width: 24)
        .gesture(
          DragGesture(minimumDistance: 25)
            .onEnded { value in
              guard value.translation.width > 80,
                    value.translation.width > abs(value.translation.height) * 1.5 else { return }
              send(.backToFestivalList)
            }
        )
        .accessibilityHidden(true)
    }
  }
}

private extension FestivalLiveBoardScreen {
  var model: FestivalLiveBoardScreenModel {
    return FestivalLiveBoardScreenModel(state: store.state)
  }

  @ViewBuilder
  func liveBoardContent(festival: FestivalOverview) -> some View {
    TimelineView(.periodic(
      from: .now,
      by: 30
    )) { timeline in
      let now = FestivalLiveBoardPresentation.serverNow(
        serverAt: model.liveBoard?.serverAt,
        clockAnchorAt: model.liveBoardClockAnchorAt,
        deviceNow: timeline.date
      )
      let phase = FestivalLiveBoardPresentation.phase(
        pack: model.pack,
        festival: festival,
        now: now
      )
      VStack(spacing: .zero) {
        topBar()
        if model.showsOfflineStatus {
          FCOfflineBadge(model.liveBoardReceivedAt == nil ? "오프라인 · 저장된 정보" : FestivalLiveBoardPresentation.offlineText(
            receivedAt: model.liveBoardReceivedAt,
            deviceNow: timeline.date
          ))
        }
        if let notification = store.notificationBanner {
          notificationBanner(
            notification,
            now: timeline.date
          )
          .padding(
            .horizontal,
            FestiCoreSpacing.paddingP16
          )
          .padding(
            .vertical,
            FestiCoreSpacing.paddingP8
          )
        }
        ScrollView {
          VStack(
            alignment: .leading,
            spacing: FestiCoreSpacing.paddingP24
          ) {
            if store.notificationBanner == nil {
              festivalHeader(
                now: now,
                festival: festival
              )
            }
            if let packDownload = model.packDownload {
              packDownloadCard(packDownload)
            }
            if model.liveBoardUnpublished {
              FCEmptyCard(
                icon: .music24,
                title: "라이브 보드 공개 전이에요",
                message: "축제 라이브 보드가 아직 공개되지 않았어요. 공개 후 공연과 깃발 현황을 확인해 주세요."
              )
            } else if phase == .ended {
              doneCard(
                festival: festival,
                now: now
              )
              homeCard(now: now)
              crewSection(now: now)
              if model.pack?.flagsEnabled != false {
                FestivalLiveBoardFollowedFlagSection(
                  store: store.scope(
                    state: \.liveBoardState,
                    action: \.liveBoard
                  ),
                  pack: store.displayDocument,
                  hasSession: store.hasSession,
                  showsFollowGuide: store.showsFollowGuide,
                  now: now,
                  festivalEnded: phase == .ended
                )
              }
            } else {
              if case .finalHour = phase {
                homeCard(now: now)
              }
              if model.isPackLoading {
                FestivalLiveBoardSkeletonView()
              } else {
                scheduleCards(
                  now: now,
                  deviceNow: timeline.date,
                  festival: festival
                )
              }
              if model.myScheduleUnavailable {
                HStack(spacing: FestiCoreSpacing.paddingP8) {
                  Text("내 일정을 불러오지 못했습니다.")
                    .frame(
                      maxWidth: .infinity,
                      alignment: .leading
                    )
                  Button("다시 시도") { send(.retryMySchedule) }
                    .festiCoreFont(.baseCaption1Bold)
                }
                .festiCoreFont(.baseCaption1Regular)
                .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
              }
              if !model.isPackLoading {
                if FestivalLiveBoardPresentation.countdown(
                  pack: model.pack,
                  festival: festival,
                  now: now
                ) == nil {
                  FestivalLiveBoardView(
                    rows: model.pack.map {
                      FestivalLiveBoardPresentation.stageRows(
                        FestivalLiveBoardSchedule.resolve(
                          pack: $0,
                          now: now
                        ),
                        mySetIDs: model.mySetIDs
                      )
                    } ?? [],
                    updated: FestivalLiveBoardPresentation.relativeTime(
                      model.liveBoardReceivedAt,
                      now: timeline.date
                    ),
                    source: FestivalLiveBoardPresentation.sourceLine(model.pack?.source)
                  )
                }
              }
              crewSection(now: now)
              if model.pack?.flagsEnabled != false {
                FestivalLiveBoardFollowedFlagSection(
                  store: store.scope(
                    state: \.liveBoardState,
                    action: \.liveBoard
                  ),
                  pack: store.displayDocument,
                  hasSession: store.hasSession,
                  showsFollowGuide: store.showsFollowGuide,
                  now: now,
                  festivalEnded: phase == .ended
                )
                FestivalLiveBoardActiveFlagSection(
                  store: store.scope(
                    state: \.liveBoardState,
                    action: \.liveBoard
                  ),
                  pack: store.displayDocument,
                  now: now,
                  isBeforeOpening: phase.isBeforeOpening
                )
              }
            }
          }
          .padding(
            .horizontal,
            FestiCoreSpacing.paddingP16
          )
          .padding(
            .top,
            store.notificationBanner == nil ? FestiCoreSpacing.paddingP16 : .zero
          )
        }
        .scrollIndicators(.hidden)
        .fcScrollBottomInset()
      }
    }
  }
  /// Figma S01 A2: 기수 계정이면 로고 옆에 기수 버튼을 둔다.
  @ViewBuilder
  func topBar() -> some View {
    if store.bearerFlagID != nil {
      FCTopBar(.logoBearer)
        .backgroundColor(.backgroundNormal)
        .onBearer { send(.bearerTapped) }
        .trailingAction { send(.notificationTapped) }
        .badgeCount(store.notificationUnreadCount)
    } else {
      FCTopBar(.logo)
        .backgroundColor(.backgroundNormal)
        .trailingAction { send(.notificationTapped) }
        .badgeCount(store.notificationUnreadCount)
    }
  }

  func notificationBanner(
    _ notification: UserNotificationItem,
    now: Date
  ) -> some View {
    return Button { send(.notificationTapped) } label: {
      HStack(spacing: FestiCoreSpacing.paddingP12) {
        Image(asset: NotificationInboxPresentation.icon(for: notification.type))
          .resizable()
          .frame(
            width: 16,
            height: 16
          )
          .foregroundStyle(FestiCoreSemanticColor.primaryOnPrimary.color)
          .frame(
            width: 40,
            height: 40
          )
          .background(FestiCoreSemanticColor.primaryNormal.color)
          .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r12))
          .accessibilityHidden(true)
        VStack(
          alignment: .leading,
          spacing: FestiCoreSpacing.paddingP4
        ) {
          HStack {
            Text(notification.title)
              .festiCoreFont(.baseCalloutBold)
              .festiCoreLineBox(.baseCalloutBold)
              .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
              .frame(
                maxWidth: .infinity,
                alignment: .leading
              )
            Text(NotificationInboxPresentation.time(
              for: notification,
              now: now
            ))
            .festiCoreFont(.baseCaption1Regular)
            .festiCoreLineBox(.baseCaption1Regular)
            .foregroundStyle(FestiCoreSemanticColor.labelAssistive.color)
          }
          Text(notification.body)
            .festiCoreFont(.baseFootnoteRegular)
            .festiCoreLineBox(.baseFootnoteRegular)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            .lineLimit(2)
        }
      }
      .padding(FestiCoreSpacing.paddingP16)
      .background(FestiCoreSemanticColor.backgroundElevated.color)
      .clipShape(RoundedRectangle(cornerRadius: FestiCoreRadius.r20))
    }
    .buttonStyle(.plain)
    .accessibilityHint("알림함으로 이동합니다")
  }

  /// 목록에서 받기 시작한 팩을 라이브 보드에서도 같은 진행 바·퍼센트로 보인다.
  @ViewBuilder
  func packDownloadCard(_ download: FestivalPackDownloadDisplay) -> some View {
    return FCPackDownloadProgress(download.text)
      .progress(download.progress)
      .padding(FestiCoreSpacing.paddingP16)
      .frame(
        maxWidth: .infinity,
        alignment: .leading
      )
      .background(
        FestiCoreSemanticColor.backgroundElevated.color,
        in: RoundedRectangle(cornerRadius: FestiCoreRadius.r16)
      )
  }

  func festivalHeader(
    now: Date,
    festival: FestivalOverview
  ) -> some View {
    VStack(
      alignment: .leading,
      spacing: FestiCoreSpacing.paddingP4
    ) {
      Button { send(.festivalSwitchTapped) } label: {
        HStack(spacing: FestiCoreSpacing.paddingP8) {
          Text(festival.name)
            .lineLimit(2)
            .fixedSize(
              horizontal: false,
              vertical: true
            )
          // Figma S01 Festival Title: Chevron Down은 chevron-right 20을 90도 돌린 것이다.
          Image(asset: .chevronRight20)
            .resizable()
            .frame(
              width: 20,
              height: 20
            )
            .rotationEffect(.degrees(90))
        }
        .festiCoreFont(.baseTitle2Bold)
        // Figma S01 헤더는 줄 높이 박스 기준으로 배치된다.
        .festiCoreLineBox(.baseTitle2Bold)
        .foregroundStyle(FestiCoreSemanticColor.labelNormal.color)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("페스티벌 바꾸기, \(festival.name)")
      if let dayLine = FestivalLiveBoardPresentation.dayLine(
        pack: model.pack,
        festival: festival,
        now: now
      ) {
        Text(dayLine)
          .festiCoreFont(.baseFootnoteRegular)
          .festiCoreLineBox(.baseFootnoteRegular)
          .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
      }
    }
    .frame(
      maxWidth: .infinity,
      alignment: .leading
    )
  }

  @ViewBuilder
  func scheduleCards(
    now: Date,
    deviceNow: Date,
    festival: FestivalOverview
  ) -> some View {
    let countdown = FestivalLiveBoardPresentation.countdown(
      pack: model.pack,
      festival: festival,
      now: now
    )
    if let countdown {
      FCCountdownCard(
        label: "개장까지",
        time: countdown.time,
        sub: countdown.sub
      )
    }
    if let card = FestivalLiveBoardPresentation.setCard(
      pack: model.pack,
      mySetIDs: model.mySetIDs,
      isBeforeOpening: countdown != nil,
      now: now
    ) {
      FCNextSetCard(
        artist: card.artist,
        meta: card.meta,
        remain: card.remain,
        updated: FestivalLiveBoardPresentation.updatedText(
          receivedAt: model.liveBoardReceivedAt,
          deviceNow: deviceNow
        ),
        progress: card.progress
      )
      .label(card.label)
    } else if model.pack == nil, store.onlineDetailFailed {
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP8
      ) {
        FCEmptyCard(
          icon: .music24,
          title: "시간표를 불러오지 못했어요",
          message: "네트워크를 확인하고 다시 시도해 주세요."
        )
        Button(
          "다시 시도",
          action: { send(.onlineDetailOnAppear) }
        )
        .festiCoreFont(.baseCaption1Bold)
      }
    } else {
      FCEmptyCard(
        icon: .music24,
        title: "다음 공연이 없습니다",
        message: model.pack == nil ? "시간표를 불러오면 다음 공연을 볼 수 있어요." : "공식 시간표에 예정된 공연이 없습니다."
      )
    }
  }

  @ViewBuilder
  func homeCard(now: Date) -> some View {
    if let ride = model.homeRide(now: now) {
      FCHomeCard(
        remain: ride.remain,
        shuttle: ride.shuttle,
        train: ride.train,
        actions: [
          FCCardAction(
            "가는 길",
            style: .ink
          ) { send(.homeDirectionsTapped) },
          FCCardAction(
            "같이 귀가",
            style: .inkOutline
          ) { send(.homeTogetherTapped) },
        ]
      )
      // 귀가 카드가 보일 때 도보 시간을 계산한다. 위치 권한은 아직 정하지 않았을 때만 묻는다.
      .onAppear { send(.homeRideAppeared) }
    } else if model.isHomeRideLoading {
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: 204)
        .accessibilityLabel("귀가 정보를 불러오는 중")
    }
  }

  @ViewBuilder
  func doneCard(
    festival: FestivalOverview,
    now: Date
  ) -> some View {
    if let summary = model.doneSummary(now: now) {
      FCDoneCard(
        title: "오늘 재미있게 즐겼나요?",
        sub: FestivalLiveBoardPresentation.doneSubtitle(
          pack: model.pack,
          festival: festival,
          now: now
        ),
        stats: [
          .init(
            value: "\(summary.seenSetCount)",
            label: "본 공연"
          ),
          .init(
            value: "\(summary.crewCount)명",
            label: "함께한 크루"
          ),
          .init(
            value: "\(summary.followedFlagCount)",
            label: "팔로우한 깃발"
          ),
        ]
      )
    } else if model.hasSession, model.myScheduleUnavailable {
      FCEmptyCard(
        title: "오늘의 기록을 불러오지 못했어요",
        message: "연결을 확인한 뒤 다시 시도해 주세요."
      )
      .action(FCCardAction("다시 시도") { send(.retryMySchedule) })
    } else if model.hasSession, model.liveBoardUnavailable {
      FCEmptyCard(
        title: "오늘의 기록을 불러오지 못했어요",
        message: "연결을 확인한 뒤 다시 시도해 주세요."
      )
      .action(FCCardAction("다시 시도") { send(.retryLiveBoard) })
    } else if model.hasSession {
      FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r16))
        .frame(height: 164)
        .accessibilityLabel("오늘의 공연 요약을 불러오는 중")
    }
  }

  func crewSection(now: Date) -> some View {
    return FestivalLiveBoardCrewSection(
      store: store.scope(
        state: \.liveBoardState,
        action: \.liveBoard
      ),
      pack: model.pack,
      hasSession: model.hasSession,
      sessionUserID: model.sessionUserID,
      showsGather: store.selectedFestival.map {
        FestivalLiveBoardPresentation.phase(
          pack: model.pack,
          festival: $0,
          now: now
        ) != .ended
      } ?? false,
      showsOfflineStatus: model.showsOfflineStatus,
      now: now
    )
  }

}
