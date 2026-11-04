//
//  PackDetailFeature.swift
//  Profile
//
//  Created by FestiCore on 11/3/26.
//

import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation
import ProfileInterface

/// 받은 팩 상세. 가는 길·준비물·팩 관리 탭을 보여 준다.
@Reducer
public struct PackDetailFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public let festivalID: String
    public var title: String
    public var tab = Tab.directions
    public var load = Load.loading
    public var detail: FestivalPackDetail?
    public var checklist = FestivalChecklist()
    public var isEditingChecklist = false
    public var newItemText = ""
    /// 새 버전이 있을 때 서버가 알려 준 변경 요약
    public var changes: FestivalPackChanges?
    public var isUpdating = false
    public var isDeleting = false
    /// 팩 관리 탭 아래에 잠깐 보이는 결과 문구
    public var manageMessage: String?
    public var autoDownloadOnWiFi = true
    @Presents public var destination: Destination.State?

    public init(festivalID: String, title: String) {
      self.festivalID = festivalID
      self.title = title
    }
  }

  public enum Tab: Int, CaseIterable, Equatable, Sendable {
    case directions
    case checklist
    case manage
  }

  public enum Load: Equatable, Sendable {
    case loading
    case loaded
    /// 기기에서 팩이 사라졌다.
    case missing
    case failed
  }

  /// 준비물 목록의 한 줄
  public struct ChecklistRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let isRequired: Bool
    public let isChecked: Bool
  }

  @Reducer
  public enum Destination {
    case alert(FCConfirmAlert)
  }

  private enum CancelID { case load, update, changes }

  @CasePathable
  public enum Action: ViewAction, BindableAction, Equatable {
    case binding(BindingAction<State>)
    case destination(PresentationAction<Destination.Action>)
    case view(View)
    case async(AsyncAction)
    case inner(InnerAction)
    case delegate(DelegateAction)
  }

  // MARK: - ViewAction

  @CasePathable
  public enum View: Equatable {
    case onAppear
    case backTapped
    case tabSelected(Tab)
    case linkTapped(URL)
    case retryTapped
    case itemToggled(String)
    case editTapped
    case editDoneTapped
    case itemRemoved(String)
    case addItemTapped
    case updateTapped
    case checkUpdateTapped
    case autoDownloadToggled(Bool)
    case deleteTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case load
    case fetchChanges(fromVersion: Int)
    case update
    case delete
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case loaded(FestivalPackDetail?, FestivalChecklist, autoDownloadOnWiFi: Bool)
    case loadFailed
    case changesLoaded(FestivalPackChanges)
    case updateFinished(FestivalPackDetail?)
    case updateFailed(UpdateFailure)
    case deleteFinished
    case deleteFailed
  }

  /// 업데이트를 받지 못한 이유. 사용자에게 다른 안내를 보여 준다.
  public enum UpdateFailure: Equatable, Sendable {
    case retryLater
    case offline
    case other
  }

  // MARK: - DelegateAction

  /// 이동 계약은 ProfileInterface에 있다.
  public typealias DelegateAction = PackDetailDelegate

  @Dependency(\.festivalPackDetailUseCase) private var packDetailUseCase
  @Dependency(\.uuid) private var uuid
  @Dependency(\.openURL) private var openURL

  public var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .destination(let destinationAction):
        return handleDestinationAction(state: &state, action: destinationAction)

      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)

      case .async(let asyncAction):
        return handleAsyncAction(state: &state, action: asyncAction)

      case .inner(let innerAction):
        return handleInnerAction(state: &state, action: innerAction)

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension PackDetailFeature.Destination.State: Equatable {}
extension PackDetailFeature.Destination.Action: Equatable {}

// MARK: - 화면 값

public extension PackDetailFeature.State {
  /// 지운 팩 항목을 빼고 내가 추가한 항목을 뒤에 붙인다.
  var checklistRows: [PackDetailFeature.ChecklistRow] {
    let packItems = (detail?.checklist ?? [])
      .filter { $0.required || !checklist.hiddenIDs.contains($0.id) }
      .map { PackDetailFeature.ChecklistRow(
        id: $0.id, label: $0.label, isRequired: $0.required, isChecked: checklist.checkedIDs.contains($0.id)
      ) }
    let customItems = checklist.customItems.map {
      PackDetailFeature.ChecklistRow(
        id: $0.id, label: $0.label, isRequired: false, isChecked: checklist.checkedIDs.contains($0.id)
      )
    }
    return packItems + customItems
  }

  var checkedCount: Int {
    checklistRows.filter(\.isChecked).count
  }

  var trimmedNewItem: String {
    newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

extension PackDetailFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear:
      guard state.detail == nil else { return .none }
      state.load = .loading
      return .send(.async(.load))

    case .backTapped:
      return .send(.delegate(.backRequested))

    case .tabSelected(let tab):
      state.tab = tab
      if tab != .checklist { state.isEditingChecklist = false }
      return .none

    case .linkTapped(let url):
      return .run { _ in await openURL(url) }

    case .retryTapped:
      guard state.load == .failed else { return .none }
      state.load = .loading
      return .send(.async(.load))

    case .itemToggled(let id):
      if state.checklist.checkedIDs.contains(id) {
        state.checklist.checkedIDs.remove(id)
      } else {
        state.checklist.checkedIDs.insert(id)
      }
      return saveChecklist(state)

    case .editTapped:
      state.isEditingChecklist = true
      return .none

    case .editDoneTapped:
      state.isEditingChecklist = false
      state.newItemText = ""
      return .none

    case .itemRemoved(let id):
      // 운영팀 필수 항목은 지울 수 없다.
      if state.detail?.checklist.first(where: { $0.id == id })?.required == true { return .none }
      if state.checklist.customItems.contains(where: { $0.id == id }) {
        state.checklist.customItems.removeAll { $0.id == id }
      } else {
        state.checklist.hiddenIDs.insert(id)
      }
      state.checklist.checkedIDs.remove(id)
      return saveChecklist(state)

    case .addItemTapped:
      let label = state.trimmedNewItem
      guard !label.isEmpty else { return .none }
      state.checklist.customItems.append(.init(id: "custom-\(uuid().uuidString.lowercased())", label: label))
      state.newItemText = ""
      return saveChecklist(state)

    case .updateTapped, .checkUpdateTapped:
      guard !state.isUpdating, !state.isDeleting, state.detail != nil else { return .none }
      state.isUpdating = true
      state.manageMessage = nil
      return .send(.async(.update))

    case .autoDownloadToggled(let isOn):
      state.autoDownloadOnWiFi = isOn
      return .run { _ in packDetailUseCase.setAutoDownloadOnWiFi(isOn) }

    case .deleteTapped:
      guard !state.isDeleting, !state.isUpdating else { return .none }
      state.destination = .alert(.deletePack(name: state.title))
      return .none
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    let festivalID = state.festivalID
    switch action {
    case .load:
      return .run { send in
        do {
          let detail = try await packDetailUseCase.packDetail(festivalID: festivalID)
          await send(.inner(.loaded(
            detail,
            packDetailUseCase.checklist(festivalID: festivalID),
            autoDownloadOnWiFi: packDetailUseCase.autoDownloadOnWiFi()
          )))
        } catch {
          await send(.inner(.loadFailed))
        }
      }
      .cancellable(id: CancelID.load, cancelInFlight: true)

    case .fetchChanges(let fromVersion):
      return .run { send in
        // 변경 요약을 받지 못해도 업데이트 받기는 할 수 있다.
        if let changes = try? await packDetailUseCase.packChanges(festivalID: festivalID, fromVersion: fromVersion) {
          await send(.inner(.changesLoaded(changes)))
        }
      }
      .cancellable(id: CancelID.changes, cancelInFlight: true)

    case .update:
      return .run { send in
        do {
          await send(.inner(.updateFinished(try await packDetailUseCase.updatePack(festivalID: festivalID))))
        } catch FestivalPackError.retryLater {
          await send(.inner(.updateFailed(.retryLater)))
        } catch FestivalPackError.offline {
          await send(.inner(.updateFailed(.offline)))
        } catch {
          await send(.inner(.updateFailed(.other)))
        }
      }
      .cancellable(id: CancelID.update, cancelInFlight: true)

    case .delete:
      return .run { send in
        do {
          try await packDetailUseCase.deletePack(festivalID: festivalID)
          await send(.inner(.deleteFinished))
        } catch {
          await send(.inner(.deleteFailed))
        }
      }
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loaded(detail, checklist, autoDownloadOnWiFi):
      state.checklist = checklist
      state.autoDownloadOnWiFi = autoDownloadOnWiFi
      guard let detail else {
        state.load = .missing
        return .none
      }
      state.detail = detail
      state.title = detail.pack.name
      state.load = .loaded
      return fetchChangesIfNeeded(state)

    case .loadFailed:
      state.load = .failed
      return .none

    case .changesLoaded(let changes):
      guard changes.fromVersion == state.detail?.pack.packVersion else { return .none }
      state.changes = changes
      return .none

    case .updateFinished(let detail):
      state.isUpdating = false
      guard let detail else {
        state.load = .missing
        return .send(.delegate(.packChanged))
      }
      let updated = detail.pack.packVersion != state.detail?.pack.packVersion
      state.detail = detail
      state.changes = nil
      state.manageMessage = updated ? "새 버전 v\(detail.pack.packVersion)을 받았어요" : "최신 버전이에요"
      return .merge(.send(.delegate(.packChanged)), fetchChangesIfNeeded(state))

    case .updateFailed(let failure):
      state.isUpdating = false
      switch failure {
      case .retryLater:
        state.manageMessage = "지금은 받는 사람이 많아요. 잠시 후 다시 시도해 주세요."
      case .offline:
        state.manageMessage = "인터넷에 연결되어 있지 않아요. 연결을 확인한 뒤 다시 시도해 주세요."
      case .other:
        state.manageMessage = "업데이트를 확인하지 못했어요. 잠시 후 다시 시도해 주세요."
      }
      return .none

    case .deleteFinished:
      state.isDeleting = false
      return .send(.delegate(.packDeleted))

    case .deleteFailed:
      state.isDeleting = false
      state.manageMessage = "팩을 삭제하지 못했어요. 다시 시도해 주세요."
      return .none
    }
  }

  private func handleDestinationAction(
    state: inout State,
    action: PresentationAction<Destination.Action>
  ) -> Effect<Action> {
    switch action {
    case .presented(.alert(.confirmTapped)):
      state.destination = nil
      guard !state.isDeleting else { return .none }
      state.isDeleting = true
      // 확인 팝업이 떠 있는 동안 시작한 업데이트가 지운 팩을 다시 받지 않게 멈춘다.
      state.isUpdating = false
      return .run { send in
        Task.cancel(id: CancelID.update)
        await send(.async(.delete))
      }

    case .presented(.alert(.cancelTapped)):
      state.destination = nil
      return .none

    case .dismiss:
      return .none
    }
  }

  private func fetchChangesIfNeeded(_ state: State) -> Effect<Action> {
    guard let pack = state.detail?.pack, pack.hasUpdate else { return .none }
    return .send(.async(.fetchChanges(fromVersion: pack.packVersion)))
  }

  private func saveChecklist(_ state: State) -> Effect<Action> {
    let checklist = state.checklist
    let festivalID = state.festivalID
    return .run { _ in packDetailUseCase.saveChecklist(checklist, festivalID: festivalID) }
  }
}
