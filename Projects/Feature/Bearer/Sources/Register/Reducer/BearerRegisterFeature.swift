//
//  BearerRegisterFeature.swift
//  Bearer
//
//  Created by FestiCore on 11/12/26.
//

import BearerDomainInterface
import BearerInterface
import ComposableArchitecture
import FestiCoreSharedUI
import FestivalDomainInterface
import Foundation

/// Figma S14 D1·D2 코드 없는 깃발 프로필 등록과 E1·E2 저장 완료.
/// 페스티벌은 받은 팩을 먼저, 그다음 서버의 앞으로 열리는 페스티벌을 보인다.
@Reducer
public struct BearerRegisterFeature {
  public init() {}

  /// 처음에 보이는 '앞으로 열리는 페스티벌' 수
  static let upcomingPreviewCount = 3

  @ObservableState
  public struct State: Equatable {
    /// 먼저 골라 둘 페스티벌(라이브 탭에서 연 페스티벌)
    public let preferredFestivalID: String?
    public var festivals = FestivalList()
    public var selectedFestivalID: String?
    /// 고른 페스티벌의 받은 팩에서 읽은 존. 팩이 없으면 비어 있어 존 고르기를 숨긴다.
    public var zones: [BearerZone] = []
    public var form = Form()
    /// 등록한 뒤 올릴 사진
    public var photoData: Data?
    public var isSaving = false
    public var nameError: String?
    public var saveError: String?
    /// 마지막으로 보낸 등록. 같은 내용을 다시 보내면 같은 멱등키를 쓴다.
    public var pendingRequest: BearerRegisterRequest?
    public var completion: Completion?
    @Presents public var destination: Destination.State?

    public init(preferredFestivalID: String? = nil) {
      self.preferredFestivalID = preferredFestivalID
    }
  }

  /// 페스티벌 후보 목록. 받은 팩이 있으면 '내가 받은 팩'·'다른 페스티벌'로 나눠 보인다.
  public struct FestivalList: Equatable, Sendable {
    public var load = Load.loading
    public var received: [BearerFestivalOption] = []
    public var upcoming: [BearerFestivalOption] = []
    public var showsAllUpcoming = false

    public init() {}

    public var visibleUpcoming: [BearerFestivalOption] {
      return showsAllUpcoming ? upcoming : Array(upcoming.prefix(BearerRegisterFeature.upcomingPreviewCount))
    }

    public var canShowMore: Bool {
      return !showsAllUpcoming && upcoming.count > BearerRegisterFeature.upcomingPreviewCount
    }

    public var isEmpty: Bool {
      return received.isEmpty && upcoming.isEmpty
    }

    func option(_ id: String?) -> BearerFestivalOption? {
      guard let id else { return nil }
      return (received + upcoming).first { $0.id == id }
    }
  }

  public enum Load: Equatable, Sendable {
    case loading
    case loaded
    case failed(offline: Bool)
  }

  /// 입력한 깃발 프로필
  public struct Form: Equatable, Sendable {
    public var name = ""
    public var bio = ""
    public var tags: [BearerFlagTag] = []
    public var homeZoneID: String?
    public var planVisible = true

    public init() {}
  }

  /// 저장 완료(E). 팩이 없으면 팩 받기를 권한다(E1), 있으면 공동 기수 초대를 둔다(E2).
  public struct Completion: Equatable, Sendable {
    public let claim: BearerClaim
    public let festival: BearerFestivalOption
    public var photo = PhotoStatus.none
    public var isInviting = false

    public enum PhotoStatus: Equatable, Sendable {
      case none
      case uploading
      case uploaded(BearerFlagPhoto)
      case failed
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
    case nameChanged(String)
    case bioChanged(String)
    case tagTapped(BearerFlagTag)
    case zoneTapped(String)
    case planVisibleChanged(Bool)
    case photoPicked(Data)
    case saveTapped
    case claimTapped
    case laterTapped
    case backTapped
    /// 저장 완료의 첫 버튼(E1 팩 받기·E2 완료)
    case primaryDoneTapped
    /// 저장 완료의 둘째 버튼(E1 나중에 받을게요·E2 공동 기수 초대하기)
    case secondaryDoneTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case loadFestivals
    case loadZones(String)
    case register(BearerRegisterRequest)
    case uploadPhoto(
      flagID: String,
      data: Data
    )
    case invite(String)
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case festivalsLoaded(
      received: [BearerFestivalOption],
      upcoming: [BearerFestivalOption]
    )
    case festivalsFailed(offline: Bool)
    case zonesLoaded(
      festivalID: String,
      zones: [BearerZone]
    )
    case registered(BearerClaim)
    case registerFailed(BearerError)
    case photoUploaded(BearerFlagPhoto)
    case photoFailed
    case invited(BearerInvite)
    case inviteFailed(BearerError)
  }

  // MARK: - Destination

  @Reducer(
    state: .equatable,
    action: .equatable
  )
  public enum Destination {
    case alert(FCConfirmAlert)
  }

  // MARK: - DelegateAction

  public typealias DelegateAction = BearerRegisterDelegate

  enum CancelID {
    case festivals
    case zones
    case register
    case upload
    case invite
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

extension BearerRegisterFeature.State {
  var trimmedName: String {
    return form.name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public var selectedFestival: BearerFestivalOption? {
    return festivals.option(selectedFestivalID)
  }

  public var canSave: Bool {
    return selectedFestival != nil
      && BearerProfileFeature.nameRange.contains(trimmedName.unicodeScalars.count)
      && form.bio.unicodeScalars.count <= BearerProfileFeature.bioLimit
      && form.tags.count <= BearerProfileFeature.tagLimit
      && nameError == nil
      && !isSaving
  }

  /// 태그를 고르지 않으면 서버 기본값과 같은 '초보 환영'으로 보낸다.
  var change: BearerProfileChange {
    return BearerProfileChange(
      name: trimmedName,
      bio: form.bio,
      tags: form.tags.isEmpty ? [.newbie] : form.tags,
      planVisible: form.planVisible,
      homeZoneID: form.homeZoneID
    )
  }
}

extension BearerRegisterFeature {
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
      // 저장 중에는 등록 요청의 페스티벌이 바뀌지 않게 고르기를 막는다.
      guard !state.isSaving, state.selectedFestivalID != festivalID else { return .none }
      return select(
        festivalID,
        state: &state
      )

    case .showMoreTapped:
      state.festivals.showsAllUpcoming = true
      return .none

    case .nameChanged(let text):
      state.form.name = BearerProfileFeature.prefix(
        text,
        scalars: BearerProfileFeature.nameRange.upperBound
      )
      state.nameError = nil
      state.saveError = nil
      return .none

    case .bioChanged(let text):
      state.form.bio = BearerProfileFeature.prefix(
        text,
        scalars: BearerProfileFeature.bioLimit
      )
      return .none

    case .tagTapped(let tag):
      if let index = state.form.tags.firstIndex(of: tag) {
        state.form.tags.remove(at: index)
      } else if state.form.tags.count < BearerProfileFeature.tagLimit {
        state.form.tags.append(tag)
      }
      return .none

    case .zoneTapped(let zoneID):
      state.form.homeZoneID = state.form.homeZoneID == zoneID ? nil : zoneID
      return .none

    case .planVisibleChanged(let isVisible):
      state.form.planVisible = isVisible
      return .none

    case .photoPicked(let data):
      state.photoData = data
      return .none

    case .saveTapped:
      guard state.canSave, let festival = state.selectedFestival else { return .none }
      let change = state.change
      let request: BearerRegisterRequest
      if let pending = state.pendingRequest, pending.festivalID == festival.id, pending.change == change {
        // 응답을 받지 못한 같은 등록은 같은 멱등키로 다시 보내 깃발이 두 개 생기지 않게 한다.
        request = pending
      } else {
        request = bearerUseCase.makeRegisterRequest(
          festivalID: festival.id,
          change: change
        )
      }
      state.pendingRequest = request
      state.isSaving = true
      state.saveError = nil
      return .send(.async(.register(request)))

    case .claimTapped:
      guard let festivalID = state.selectedFestivalID else { return .none }
      return .send(.delegate(.claimRequested(festivalID: festivalID)))

    case .laterTapped:
      return .merge(
        .cancel(id: CancelID.register),
        .send(.delegate(.closeRequested))
      )

    case .backTapped:
      return .merge(
        .cancel(id: CancelID.register),
        .send(.delegate(.backRequested))
      )

    case .primaryDoneTapped:
      guard let completion = state.completion else { return .none }
      if completion.festival.hasPack {
        return .send(.delegate(.finished(festivalID: completion.festival.id)))
      }
      return .send(.delegate(.packRequested(festivalID: completion.festival.id)))

    case .secondaryDoneTapped:
      guard let completion = state.completion else { return .none }
      guard completion.festival.hasPack else {
        return .send(.delegate(.finished(festivalID: completion.festival.id)))
      }
      guard !completion.isInviting else { return .none }
      state.completion?.isInviting = true
      return .send(.async(.invite(completion.claim.flagID)))
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .loadFestivals:
      let today = Self.dayString(
        now,
        calendar: calendar
      )
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
        let options = Self.options(
          packs: packs,
          catalog: catalog,
          today: today
        )
        guard !(options.received.isEmpty && options.upcoming.isEmpty) else {
          await send(.inner(.festivalsFailed(offline: isOffline)))
          return
        }
        await send(.inner(.festivalsLoaded(
          received: options.received,
          upcoming: options.upcoming
        )))
      }
      .cancellable(
        id: CancelID.festivals,
        cancelInFlight: true
      )

    case .loadZones(let festivalID):
      return .run { send in
        let festival = try? await bearerUseCase.fetchFestival(festivalID: festivalID)
        await send(.inner(.zonesLoaded(
          festivalID: festivalID,
          zones: festival?.zones ?? []
        )))
      }
      .cancellable(
        id: CancelID.zones,
        cancelInFlight: true
      )

    case .register(let request):
      return .run { send in
        do {
          await send(.inner(.registered(try await bearerUseCase.register(request))))
        } catch let error as BearerError {
          await send(.inner(.registerFailed(error)))
        } catch is CancellationError {
          return
        } catch {
          await send(.inner(.registerFailed(.unavailable)))
        }
      }
      .cancellable(
        id: CancelID.register,
        cancelInFlight: true
      )

    case let .uploadPhoto(flagID, data):
      return .run { send in
        do {
          for try await event in bearerUseCase.uploadPhoto(
            flagID: flagID,
            imageData: data
          ) {
            if case .completed(let photo) = event {
              await send(.inner(.photoUploaded(photo)))
            }
          }
        } catch is CancellationError {
          return
        } catch {
          await send(.inner(.photoFailed))
        }
      }
      .cancellable(
        id: CancelID.upload,
        cancelInFlight: true
      )

    case .invite(let flagID):
      return .run { send in
        do {
          await send(.inner(.invited(try await bearerUseCase.inviteCoBearer(flagID: flagID))))
        } catch let error as BearerError {
          await send(.inner(.inviteFailed(error)))
        } catch {
          await send(.inner(.inviteFailed(.unavailable)))
        }
      }
      .cancellable(
        id: CancelID.invite,
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
      // 고른 페스티벌이 목록에 그대로 있으면 유지하고, 없으면 라이브에서 연 페스티벌·첫 받은 팩 순으로 고른다.
      if state.selectedFestival != nil { return .none }
      let preferred = state.festivals.option(state.preferredFestivalID) ?? received.first
      guard let preferred else {
        state.selectedFestivalID = nil
        return .none
      }
      return select(
        preferred.id,
        state: &state
      )

    case let .festivalsFailed(offline):
      state.festivals.load = .failed(offline: offline)
      return .none

    case let .zonesLoaded(festivalID, zones):
      guard state.selectedFestivalID == festivalID else { return .none }
      state.zones = zones
      if let zoneID = state.form.homeZoneID, !zones.contains(where: { $0.id == zoneID }) {
        state.form.homeZoneID = nil
      }
      return .none

    case .registered(let claim):
      // 완료·핀은 화면의 현재 선택이 아니라 실제로 보낸 요청의 페스티벌을 기준으로 한다.
      let requestedFestivalID = state.pendingRequest?.festivalID ?? state.selectedFestivalID
      state.isSaving = false
      state.pendingRequest = nil
      guard let festival = state.festivals.option(requestedFestivalID) else { return .none }
      var completion = Completion(
        claim: claim,
        festival: festival
      )
      var effects: [Effect<Action>] = [
        .send(.delegate(.registered(
          flagID: claim.flagID,
          festivalID: festival.id
        )))
      ]
      if let data = state.photoData {
        completion.photo = .uploading
        effects.append(.send(.async(.uploadPhoto(
          flagID: claim.flagID,
          data: data
        ))))
      }
      state.completion = completion
      return .merge(effects)

    case .registerFailed(let error):
      state.isSaving = false
      switch error {
      case .nameTaken:
        state.nameError = "이미 있는 깃발 이름이에요. 다른 이름을 지어 주세요."
        state.destination = .alert(.bearerNameTaken())
      case .bearerLimit:
        state.destination = .alert(.bearerLimit(festivalName: state.selectedFestival?.name))
      case .offline:
        // 응답을 못 받았을 수 있으니 같은 멱등키를 남겨 다시 누르면 같은 등록으로 보낸다.
        state.saveError = BearerProfileFeature.saveMessage(for: error)
        return .none
      default:
        state.saveError = BearerProfileFeature.saveMessage(for: error)
      }
      state.pendingRequest = nil
      return .none

    case .photoUploaded(let photo):
      state.completion?.photo = .uploaded(photo)
      return .none

    case .photoFailed:
      state.completion?.photo = .failed
      return .none

    case .invited(let invite):
      state.completion?.isInviting = false
      state.destination = .alert(.coBearerInvite(code: invite.code))
      return .none

    case .inviteFailed(let error):
      state.completion?.isInviting = false
      state.destination = .alert(.coBearerInviteFailed(message: BearerProfileFeature.inviteMessage(for: error)))
      return .none
    }
  }

  private func handleDestinationAction(
    state: inout State,
    action: PresentationAction<Destination.Action>
  ) -> Effect<Action> {
    switch action {
    case .presented(.alert(.confirmTapped)), .presented(.alert(.cancelTapped)):
      state.destination = nil
      return .none

    case .dismiss, .presented:
      return .none
    }
  }

  private func select(
    _ festivalID: String,
    state: inout State
  ) -> Effect<Action> {
    state.selectedFestivalID = festivalID
    state.zones = []
    state.form.homeZoneID = nil
    guard state.selectedFestival?.hasPack == true else {
      return .cancel(id: CancelID.zones)
    }
    return .send(.async(.loadZones(festivalID)))
  }
}

// MARK: - 페스티벌 후보

extension BearerRegisterFeature {
  /// 받은 팩을 먼저, 끝나지 않은 서버 페스티벌을 시작 순으로 그다음에 둔다. 같은 페스티벌은 한 번만 보인다.
  static func options(
    packs: [FestivalReceivedPack],
    catalog: [FestivalCatalogItem],
    today: String
  ) -> (received: [BearerFestivalOption], upcoming: [BearerFestivalOption]) {
    let catalogByID = Dictionary(
      catalog.map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    let received = packs.map { pack in
      return BearerFestivalOption(
        id: pack.id,
        name: pack.name,
        dateText: catalogByID[pack.id].flatMap(dateText),
        hasPack: true
      )
    }
    let receivedIDs = Set(packs.map(\.id))
    let upcoming = catalog
      .filter { item in
        guard !receivedIDs.contains(item.id) else { return false }
        guard let last = day(item.lastDate) ?? day(item.firstDate) else { return false }
        return last >= today
      }
      .sorted { (day($0.firstDate) ?? "") < (day($1.firstDate) ?? "") }
      .map { item in
        return BearerFestivalOption(
          id: item.id,
          name: item.name,
          dateText: dateText(item),
          hasPack: false
        )
      }
    return (
      received,
      upcoming
    )
  }

  /// `2026-11-20`·`2026-11-22` → `11/20-22`, 달이 다르면 `11/30-12/1`
  static func dateText(_ item: FestivalCatalogItem) -> String? {
    guard let first = monthDay(item.firstDate) else { return nil }
    guard let last = monthDay(item.lastDate), last != first else { return "\(first.month)/\(first.day)" }
    if last.month == first.month {
      return "\(first.month)/\(first.day)-\(last.day)"
    }
    return "\(first.month)/\(first.day)-\(last.month)/\(last.day)"
  }

  static func dayString(
    _ date: Date,
    calendar: Calendar
  ) -> String {
    let parts = calendar.dateComponents(
      [.year, .month, .day],
      from: date
    )
    return String(
      format: "%04d-%02d-%02d",
      parts.year ?? 0,
      parts.month ?? 0,
      parts.day ?? 0
    )
  }

  private static func day(_ value: String?) -> String? {
    guard let value, value.count >= 10 else { return nil }
    return String(value.prefix(10))
  }

  private static func monthDay(_ value: String?) -> (month: Int, day: Int)? {
    guard let day = day(value) else { return nil }
    let parts = day.split(separator: "-")
    guard parts.count == 3, let month = Int(parts[1]), let date = Int(parts[2]) else { return nil }
    return (
      month,
      date
    )
  }
}
