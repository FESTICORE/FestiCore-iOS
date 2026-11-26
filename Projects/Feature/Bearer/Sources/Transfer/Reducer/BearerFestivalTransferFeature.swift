//
//  BearerFestivalTransferFeature.swift
//  Bearer
//
//  Created by FestiCore on 11/26/26.
//

import BearerDomainInterface
import BearerInterface
import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation

/// 깃발 상세 메뉴의 '다른 페스티벌로 옮기기'. 등록 화면과 같은 페스티벌 후보에서 하나를 골라 확인 팝업 뒤 옮긴다.
/// 이동 전용 시안이 없어 등록 화면의 페스티벌 목록·확인 팝업 스타일을 그대로 쓴다.
@Reducer
public struct BearerFestivalTransferFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let flagID: String
    /// 깃발이 지금 속한 페스티벌. 후보에서 뺀다.
    public let fromFestivalID: String
    public var festivals = BearerRegisterFeature.FestivalList()
    public var selectedFestivalID: String?
    public var isSaving = false
    /// 마지막 실패 안내
    public var errorMessage: String?
    /// 응답을 받지 못한 이동. 같은 페스티벌로 다시 보내면 같은 멱등키를 쓴다.
    public var pendingRequest: BearerFestivalTransferRequest?
    @Presents public var destination: Destination.State?

    public init(
      flagID: String,
      fromFestivalID: String
    ) {
      self.flagID = flagID
      self.fromFestivalID = fromFestivalID
    }

    public var selectedFestival: BearerFestivalOption? {
      return festivals.option(selectedFestivalID)
    }

    public var canTransfer: Bool {
      return selectedFestival != nil && !isSaving
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case destination(PresentationAction<Destination.Action>)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case retryTapped
    case festivalTapped(String)
    case showMoreTapped
    case transferTapped
    case backTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case loadFestivals
    case transfer(BearerFestivalTransferRequest)
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case festivalsLoaded(
      received: [BearerFestivalOption],
      upcoming: [BearerFestivalOption]
    )
    case festivalsFailed(offline: Bool)
    case transferred(BearerFestivalTransfer)
    case transferFailed(BearerError)
  }

  // MARK: - Destination

  @Reducer(
    state: .equatable,
    action: .equatable
  )
  public enum Destination {
    case confirm(FCConfirmAlert)
  }

  // MARK: - DelegateAction

  public typealias DelegateAction = BearerFestivalTransferDelegate

  enum CancelID {
    case festivals
    case transfer
  }

  @Dependency(\.bearerUseCase) private var bearerUseCase
  @Dependency(\.festivalCatalogUseCase) private var catalogUseCase
  @Dependency(\.festivalReceivedPackUseCase) private var receivedPackUseCase
  @Dependency(\.date.now) private var now
  @Dependency(\.calendar) private var calendar

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )

      case .async(let asyncAction):
        return handleAsyncAction(
          state: &state,
          action: asyncAction
        )

      case .inner(let innerAction):
        return handleInnerAction(
          state: &state,
          action: innerAction
        )

      case .destination(let destinationAction):
        return handleDestinationAction(
          state: &state,
          action: destinationAction
        )

      case .delegate:
        return .none
      }
    }
    .ifLet(
      \.$destination,
      action: \.destination
    )
  }
}

extension BearerFestivalTransferFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      guard state.festivals.load != .loaded else { return .none }
      state.festivals.load = .loading
      return .send(.async(.loadFestivals))

    case .retryTapped:
      state.festivals.load = .loading
      return .send(.async(.loadFestivals))

    case .festivalTapped(let festivalID):
      // 옮기는 중에는 보낸 요청의 페스티벌이 바뀌지 않게 고르기를 막는다.
      guard !state.isSaving else { return .none }
      state.selectedFestivalID = festivalID
      state.errorMessage = nil
      return .none

    case .showMoreTapped:
      state.festivals.showsAllUpcoming = true
      return .none

    case .transferTapped:
      guard state.canTransfer, let festival = state.selectedFestival else { return .none }
      state.destination = .confirm(.bearerFestivalTransfer(festivalName: festival.name))
      return .none

    case .backTapped:
      return .send(.delegate(.backRequested))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .loadFestivals:
      let today = BearerRegisterFeature.dayString(
        now,
        calendar: calendar
      )
      let fromFestivalID = state.fromFestivalID
      return .run { send in
        let packs = (try? await receivedPackUseCase.receivedPacks()) ?? []
        let catalog: [FestivalCatalogItem]
        var isOffline = false
        do {
          catalog = try await catalogUseCase.refreshFestivals()
        } catch {
          // 연결되지 않았으면 기기에 저장된 목록으로 고르게 한다.
          isOffline = true
          catalog = (try? await catalogUseCase.cachedFestivals()) ?? []
        }
        let options = BearerRegisterFeature.options(
          packs: packs,
          catalog: catalog,
          today: today
        )
        let received = options.received.filter { $0.id != fromFestivalID }
        let upcoming = options.upcoming.filter { $0.id != fromFestivalID }
        guard !(received.isEmpty && upcoming.isEmpty) else {
          await send(.inner(.festivalsFailed(offline: isOffline)))
          return
        }
        await send(.inner(.festivalsLoaded(
          received: received,
          upcoming: upcoming
        )))
      }
      .cancellable(
        id: CancelID.festivals,
        cancelInFlight: true
      )

    case .transfer(let request):
      return .run { send in
        do {
          let transfer = try await bearerUseCase.transferFestival(request)
          await send(.inner(.transferred(transfer)))
        } catch let error as BearerError {
          await send(.inner(.transferFailed(error)))
        } catch is CancellationError {
          return
        } catch {
          await send(.inner(.transferFailed(.unavailable)))
        }
      }
      .cancellable(
        id: CancelID.transfer,
        cancelInFlight: true
      )
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .festivalsLoaded(received, upcoming):
      state.festivals.received = received
      state.festivals.upcoming = upcoming
      state.festivals.load = .loaded
      return .none

    case let .festivalsFailed(offline):
      state.festivals.load = .failed(offline: offline)
      return .none

    case let .transferred(transfer):
      state.isSaving = false
      state.pendingRequest = nil
      return .send(.delegate(.transferred(
        flagID: transfer.flagID,
        festivalID: transfer.festivalID
      )))

    case let .transferFailed(error):
      state.isSaving = false
      state.errorMessage = Self.transferMessage(for: error)
      // 응답을 못 받았을 수 있을 때만 같은 멱등키를 남겨 다시 누르면 같은 이동으로 보낸다.
      if error != .offline { state.pendingRequest = nil }
      return .none
    }
  }

  private func handleDestinationAction(
    state: inout State,
    action: PresentationAction<Destination.Action>
  ) -> Effect<Action> {
    switch action {
    case .presented(.confirm(.confirmTapped)):
      state.destination = nil
      guard let toFestivalID = state.selectedFestivalID, !state.isSaving else { return .none }
      let request: BearerFestivalTransferRequest
      if let pending = state.pendingRequest, pending.toFestivalID == toFestivalID {
        request = pending
      } else {
        request = bearerUseCase.makeFestivalTransferRequest(
          flagID: state.flagID,
          fromFestivalID: state.fromFestivalID,
          toFestivalID: toFestivalID
        )
      }
      state.pendingRequest = request
      state.isSaving = true
      state.errorMessage = nil
      return .send(.async(.transfer(request)))

    case .presented(.confirm(.cancelTapped)):
      state.destination = nil
      return .none

    case .dismiss, .presented:
      return .none
    }
  }
}

extension BearerFestivalTransferFeature {
  /// 서버 거절 코드(백엔드 #409)별 안내
  static func transferMessage(for error: BearerError) -> String {
    switch error {
    case .festivalMismatch: return "이미 다른 페스티벌로 옮겨진 깃발이에요. 깃발 상세를 다시 열어 확인해 주세요"
    case .hasCoBearers: return "공동 기수가 있는 깃발은 옮길 수 없어요"
    case .bearerLimit: return "옮길 페스티벌에 이미 내 깃발이 있어요. 페스티벌마다 깃발은 하나만 맡을 수 있어요"
    case .nameTaken: return "옮길 페스티벌에 같은 이름의 깃발이 있어요. 이름을 바꾼 뒤 다시 옮겨 주세요"
    case .bearerModeOff: return "기수 모드가 꺼져 있어요. 마이에서 기수 모드를 켠 뒤 다시 옮겨 주세요"
    case .notOwner: return "처음 깃발을 만든 기수만 옮길 수 있어요"
    case .termsRequired: return "새 약관에 동의한 뒤에 옮겨 주세요"
    case .notFound: return "깃발이나 페스티벌을 찾지 못했어요"
    case .conflict: return "이미 처리 중인 요청이에요. 잠시 후 다시 시도해 주세요"
    case .notAuthenticated: return "로그인한 뒤에 옮겨 주세요"
    case .offline, .notBearer: return BearerProfileFeature.saveMessage(for: error)
    default: return "깃발을 옮기지 못했어요. 잠시 후 다시 시도해 주세요"
    }
  }
}
