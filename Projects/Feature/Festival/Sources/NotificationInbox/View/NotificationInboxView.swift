import ComposableArchitecture
import FestiCoreDesignKit
import FestiCoreSharedUI
import SwiftUI
import UserNotificationDomainInterface

@ViewAction(for: NotificationInboxFeature.self)
public struct NotificationInboxView: View {
  @Bindable public var store: StoreOf<NotificationInboxFeature>
  @Dependency(\.date) private var date

  public init(store: StoreOf<NotificationInboxFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: .zero) {
      topBar()
      TimelineView(.periodic(from: .now, by: 60)) { _ in
        content(now: date.now)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(FestiCoreSemanticColor.backgroundElevated.color)
    .toolbar(.hidden, for: .navigationBar)
    .safeAreaInset(edge: .bottom, spacing: .zero) {
      if store.isEditing { selectionBar }
    }
    .fcAlert($store.scope(state: \.alert, action: \.alert))
    .onAppear { send(.onAppear) }
    .animation(.easeInOut(duration: 0.2), value: store.isEditing)
    .animation(.easeInOut(duration: 0.2), value: store.selectedIDs)
  }
}

private extension NotificationInboxView {
  @ViewBuilder
  func topBar() -> some View {
    if store.isEditing {
      FCTopBar(
        .back,
        title: "\(store.selectedIDs.count)개 선택"
      )
        .backgroundColor(.backgroundNormal)
        .onBack { send(.backTapped) }
        .trailingAction(
          icon: .xmark16,
          accessibilityLabel: "선택 취소"
        ) { send(.cancelSelectionTapped) }
    } else {
      if store.load == .loaded, !store.items.isEmpty {
        FCTopBar(
          .back,
          title: "알림"
        )
          .backgroundColor(.backgroundNormal)
          .onBack { send(.backTapped) }
          .trailingAction(icon: .trashCan20, accessibilityLabel: "알림 선택 삭제") {
            send(.editTapped)
          }
      } else {
        FCTopBar(
          .back,
          title: "알림"
        )
          .backgroundColor(.backgroundNormal)
          .onBack { send(.backTapped) }
      }
    }
  }

  @ViewBuilder
  func content(now: Date) -> some View {
    switch store.load {
    case .idle, .loading:
      loadingContent
    case .failed:
      messageContent("알림을 불러오지 못했어요", retry: true)
    case .loaded where store.items.isEmpty:
      messageContent("새로운 알림이 없어요", retry: false)
    case .loaded:
      notificationList(now: now)
    }
  }

  func notificationList(now: Date) -> some View {
    ScrollView {
      LazyVStack(spacing: .zero) {
        ForEach(NotificationInboxPresentation.sections(store.items, now: now)) { section in
          Text(section.title)
            .festiCoreFont(.baseCaption1Bold)
            .festiCoreLineBox(.baseCaption1Bold)
            .foregroundStyle(FestiCoreSemanticColor.labelNeutral.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FestiCoreSpacing.paddingP16)
            .padding(.top, FestiCoreSpacing.paddingP20)
            .padding(.bottom, FestiCoreSpacing.paddingP8)
            .accessibilityAddTraits(.isHeader)
          ForEach(section.items, id: \.id) { item in
            let isRead = item.readAt != nil || store.locallyReadIDs.contains(item.id)
            Button { send(.rowTapped(item.id)) } label: {
              FCNotificationRow(
                title: item.title,
                message: item.body,
                time: NotificationInboxPresentation.time(for: item, now: now),
                isRead: isRead
              )
              .icon(NotificationInboxPresentation.icon(for: item.type))
              .editing(store.isEditing, isSelected: store.selectedIDs.contains(item.id))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
              "\(item.title), \(item.body), \(NotificationInboxPresentation.time(for: item, now: now))"
            )
            .accessibilityValue(isRead ? "읽음" : "안 읽음")
            .accessibilityAddTraits(store.isEditing && store.selectedIDs.contains(item.id) ? .isSelected : [])
            .accessibilityHint(store.isEditing ? "선택 상태를 바꿉니다" : "알림을 엽니다")
            .onAppear {
              if item.id == store.items.last?.id { send(.loadMoreTapped) }
            }
          }
        }
        if store.isLoadingMore {
          ProgressView()
            .tint(FestiCoreSemanticColor.labelNeutral.color)
            .padding(FestiCoreSpacing.paddingP16)
            .accessibilityLabel("알림을 더 불러오는 중")
        } else if store.nextCursor != nil, !store.isEditing {
          FCButton("알림 더 보기") { send(.loadMoreTapped) }
            .style(.ghost)
            .size(.medium)
            .padding(FestiCoreSpacing.paddingP16)
        }
      }
    }
    .scrollIndicators(.hidden)
  }

  var loadingContent: some View {
    VStack(spacing: .zero) {
      ForEach(0..<5) { _ in
        HStack(spacing: FestiCoreSpacing.paddingP12) {
          FCSkeletonView(.circle).frame(width: 40, height: 40)
          VStack(alignment: .leading, spacing: FestiCoreSpacing.paddingP8) {
            FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r4)).frame(height: 18)
            FCSkeletonView(.round(cornerRadius: FestiCoreRadius.r4)).frame(width: 180, height: 14)
          }
        }
        .padding(FestiCoreSpacing.paddingP16)
      }
      Spacer()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("알림을 불러오는 중")
  }

  func messageContent(_ message: String, retry: Bool) -> some View {
    VStack(spacing: FestiCoreSpacing.paddingP12) {
      FCEmptyCard(
        icon: .bell16,
        title: message,
        message: retry ? "연결을 확인하고 다시 시도해 주세요." : "새 소식이 오면 이곳에서 확인할 수 있어요."
      )
      if retry {
        FCButton("다시 시도") { send(.retryTapped) }
          .style(.secondary)
          .size(.medium)
      }
    }
    .padding(FestiCoreSpacing.paddingP16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  var selectionBar: some View {
    HStack(spacing: FestiCoreSpacing.paddingP8) {
      FCButton(store.allLoadedSelected ? "선택 해제" : "전체 선택") { send(.selectAllTapped) }
        .style(.secondary)
        .isFullWidth(true)
      FCButton("삭제 (\(store.selectedIDs.count))") { send(.deleteTapped) }
        .style(.accent)
        .isFullWidth(true)
        .isEnabled(!store.selectedIDs.isEmpty && !store.isDeleting)
    }
    .padding(.horizontal, FestiCoreSpacing.paddingP16)
    .padding(
      .vertical,
      FestiCoreSpacing.paddingP16
    )
    .overlay(alignment: .top) {
      FestiCoreSemanticColor.lineNormal.color.frame(height: 1)
    }
    .background(FestiCoreSemanticColor.backgroundElevated.color)
  }
}
