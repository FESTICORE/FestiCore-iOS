//
//  BearerProfileFeature.swift
//  Bearer
//
//  Created by FestiCore on 11/3/26.
//

import BearerDomainInterface
import BearerInterface
import ComposableArchitecture
import FestiCoreSharedUI
import Foundation

/// Figma S10 A~E 깃발 프로필(처음·입력 완료·이름 중복·사진 업로드 중·저장 완료)
@Reducer
public struct BearerProfileFeature {
  public init() {}

  static let nameRange = 2 ... 20
  static let bioLimit = 60
  static let tagLimit = 3

  @ObservableState
  public struct State: Equatable {
    public let festivalID: String
    public let flagID: String
    /// 코드로 막 기수가 된 경우. 제목과 저장 버튼 문구가 다르다.
    public let isNewBearer: Bool
    public var festivalName: String?
    public var zones: [BearerZone] = []
    public var isLoading: Bool
    public var loadFailed = false

    public var name = ""
    public var bio = ""
    public var tags: [BearerFlagTag] = []
    public var homeZoneID: String?
    public var planVisible = true
    /// 오늘 계획으로 고른 공연 ID(내 일정에서 고른 셋)
    public var plan: [String] = []
    public var bearerCount = 1

    public var photoURL: URL?
    /// 마지막으로 올리기에 성공한 사진
    public var uploadedPhotoData: Data?
    public var photoUpload: PhotoUpload = .idle

    public var nameError: String?
    public var saveError: String?
    public var isSaving = false
    public var isInviting = false
    /// 저장을 마치면 완료 화면(E)을 보여 준다.
    public var savedProfile: BearerFlagProfile?
    @Presents public var destination: Destination.State?

    /// - Parameter profile: 코드 등록 응답의 프로필. 없으면 서버에서 읽는다.
    public init(festivalID: String, flagID: String, profile: BearerFlagProfile? = nil, isNewBearer: Bool = false) {
      self.festivalID = festivalID
      self.flagID = flagID
      self.isNewBearer = isNewBearer
      isLoading = profile == nil
      if let profile {
        apply(profile)
      }
    }
  }

  public enum PhotoUpload: Equatable, Sendable {
    case idle
    case uploading(data: Data, progress: Double)
    case failed(String)
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
    case nameChanged(String)
    case bioChanged(String)
    case tagTapped(BearerFlagTag)
    case zoneTapped(String)
    case planVisibleChanged(Bool)
    case planTapped
    case photoPicked(Data)
    case photoCancelTapped
    case inviteTapped
    case saveTapped
    case doneTapped
    case backTapped
  }

  // MARK: - AsyncAction 비동기 처리 액션

  @CasePathable
  public enum AsyncAction: Equatable {
    case load
    case uploadPhoto(Data)
    case save(BearerProfileChange)
    case invite
  }

  // MARK: - 앱내에서 사용하는 액션

  @CasePathable
  public enum InnerAction: Equatable {
    case loaded(BearerBoard?, BearerFestival?)
    case loadFailed
    case photoProgress(Double)
    case photoUploaded(BearerFlagPhoto)
    case photoFailed(BearerError)
    case saved(BearerFlagProfile)
    case saveFailed(BearerError)
    case invited(BearerInvite)
    case inviteFailed(BearerError)
  }

  // MARK: - Destination

  @Reducer(state: .equatable, action: .equatable)
  public enum Destination {
    case alert(FCConfirmAlert)
  }

  // MARK: - DelegateAction

  public typealias DelegateAction = BearerProfileDelegate

  enum CancelID {
    case load
    case upload
    case save
    case invite
  }

  @Dependency(\.bearerUseCase) private var bearerUseCase

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(state: &state, action: viewAction)

      case .async(let asyncAction):
        return handleAsyncAction(state: &state, action: asyncAction)

      case .inner(let innerAction):
        return handleInnerAction(state: &state, action: innerAction)

      case .destination(let destinationAction):
        return handleDestinationAction(state: &state, action: destinationAction)

      case .delegate(let delegateAction):
        return handleDelegateAction(state: &state, action: delegateAction)
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension BearerProfileFeature.State {
  var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

  public var isUploadingPhoto: Bool {
    if case .uploading = photoUpload { return true }
    return false
  }

  public var canSave: Bool {
    BearerProfileFeature.nameRange.contains(trimmedName.unicodeScalars.count)
      && bio.unicodeScalars.count <= BearerProfileFeature.bioLimit
      && (1 ... BearerProfileFeature.tagLimit).contains(tags.count)
      && nameError == nil
      && !isUploadingPhoto
      && !isSaving
      && !isLoading
  }

  var change: BearerProfileChange {
    BearerProfileChange(name: trimmedName, bio: bio, tags: tags, planVisible: planVisible, homeZoneID: homeZoneID)
  }

  /// 코드 등록 직후 서버가 붙인 임시 이름(`새 깃발 …`)과 기본 태그는 빈 입력으로 보여 준다.
  mutating func apply(_ profile: BearerFlagProfile) {
    let isPlaceholder = isNewBearer && profile.name.hasPrefix("새 깃발 ")
    name = isPlaceholder ? "" : profile.name
    bio = profile.bio ?? ""
    tags = isPlaceholder ? [] : profile.tags
    homeZoneID = profile.homeZoneID
    planVisible = profile.planVisible
    plan = profile.plan
    photoURL = profile.thumbnailURL ?? profile.photoURL
  }
}

extension BearerProfileFeature {
  private func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case .onAppear, .retryTapped:
      state.loadFailed = false
      return .send(.async(.load))

    case .nameChanged(let text):
      state.name = Self.prefix(text, scalars: Self.nameRange.upperBound)
      state.nameError = nil
      state.saveError = nil
      return .none

    case .bioChanged(let text):
      state.bio = Self.prefix(text, scalars: Self.bioLimit)
      return .none

    case .tagTapped(let tag):
      if let index = state.tags.firstIndex(of: tag) {
        state.tags.remove(at: index)
      } else if state.tags.count < Self.tagLimit {
        state.tags.append(tag)
      }
      return .none

    case .zoneTapped(let zoneID):
      state.homeZoneID = state.homeZoneID == zoneID ? nil : zoneID
      return .none

    case .planVisibleChanged(let isVisible):
      state.planVisible = isVisible
      return .none

    case .photoPicked(let data):
      guard !state.isSaving else { return .none }
      state.photoUpload = .uploading(data: data, progress: 0)
      return .send(.async(.uploadPhoto(data)))

    case .photoCancelTapped:
      guard state.isUploadingPhoto else { return .none }
      state.photoUpload = .idle
      return .cancel(id: CancelID.upload)

    case .inviteTapped:
      guard !state.isInviting else { return .none }
      state.isInviting = true
      return .send(.async(.invite))

    case .saveTapped:
      guard state.canSave else { return .none }
      state.isSaving = true
      state.saveError = nil
      return .send(.async(.save(state.change)))

    case .doneTapped:
      return .send(.delegate(.finished(flagID: state.flagID)))

    case .planTapped:
      return .send(.delegate(.planRequested(festivalID: state.festivalID)))

    case .backTapped:
      return .merge(
        .cancel(id: CancelID.upload),
        .send(.delegate(.closeRequested))
      )
    }
  }

  private func handleAsyncAction(
    state: inout State,
    action: AsyncAction
  ) -> Effect<Action> {
    switch action {
    case .load:
      let festivalID = state.festivalID
      let flagID = state.flagID
      let needsProfile = state.isLoading
      return .run { send in
        async let festival = try? bearerUseCase.fetchFestival(festivalID: festivalID)
        do {
          let board = try await bearerUseCase.fetchBoard(flagID: flagID)
          await send(.inner(.loaded(board, await festival)))
        } catch {
          // 프로필을 이미 받았으면 공동 기수 수만 못 채운 채로 입력을 계속한다.
          if needsProfile {
            _ = await festival
            await send(.inner(.loadFailed))
          } else {
            await send(.inner(.loaded(nil, await festival)))
          }
        }
      }
      .cancellable(id: CancelID.load, cancelInFlight: true)

    case .uploadPhoto(let data):
      let flagID = state.flagID
      return .run { send in
        do {
          for try await event in bearerUseCase.uploadPhoto(flagID: flagID, imageData: data) {
            switch event {
            case .progress(let fraction):
              await send(.inner(.photoProgress(fraction)))
            case .completed(let photo):
              await send(.inner(.photoUploaded(photo)))
            }
          }
        } catch let error as BearerError {
          await send(.inner(.photoFailed(error)))
        } catch is CancellationError {
          return
        } catch {
          await send(.inner(.photoFailed(.unavailable)))
        }
      }
      .cancellable(id: CancelID.upload, cancelInFlight: true)

    case .save(let change):
      let flagID = state.flagID
      return .run { send in
        do {
          let profile = try await bearerUseCase.updateProfile(flagID: flagID, change: change)
          await send(.inner(.saved(profile)))
        } catch let error as BearerError {
          await send(.inner(.saveFailed(error)))
        } catch {
          await send(.inner(.saveFailed(.unavailable)))
        }
      }
      .cancellable(id: CancelID.save, cancelInFlight: true)

    case .invite:
      let flagID = state.flagID
      return .run { send in
        do {
          await send(.inner(.invited(try await bearerUseCase.inviteCoBearer(flagID: flagID))))
        } catch let error as BearerError {
          await send(.inner(.inviteFailed(error)))
        } catch {
          await send(.inner(.inviteFailed(.unavailable)))
        }
      }
      .cancellable(id: CancelID.invite, cancelInFlight: true)
    }
  }

  private func handleInnerAction(
    state: inout State,
    action: InnerAction
  ) -> Effect<Action> {
    switch action {
    case let .loaded(board, festival):
      if let festival {
        state.festivalName = festival.name
        state.zones = festival.zones
      }
      if let board {
        if state.isLoading { state.apply(board.profile) }
        state.photoURL = board.profile.thumbnailURL ?? board.profile.photoURL
        state.bearerCount = max(1, board.coBearers.count)
      }
      state.isLoading = false
      return .none

    case .loadFailed:
      state.loadFailed = true
      return .none

    case .photoProgress(let fraction):
      guard case let .uploading(data, _) = state.photoUpload else { return .none }
      state.photoUpload = .uploading(data: data, progress: fraction)
      return .none

    case .photoUploaded(let photo):
      guard case let .uploading(data, _) = state.photoUpload else { return .none }
      state.uploadedPhotoData = data
      state.photoURL = photo.thumbnailURL ?? photo.photoURL
      state.photoUpload = .idle
      return .none

    case .photoFailed(let error):
      guard state.isUploadingPhoto else { return .none }
      state.photoUpload = .failed(Self.photoMessage(for: error))
      return .none

    case .saved(let profile):
      state.isSaving = false
      state.savedProfile = profile
      return .none

    case .saveFailed(let error):
      state.isSaving = false
      if error == .nameTaken {
        state.nameError = "이미 있는 깃발 이름이에요. 다른 이름을 지어 주세요."
      } else {
        state.saveError = Self.saveMessage(for: error)
      }
      return .none

    case .invited(let invite):
      state.isInviting = false
      state.destination = .alert(.coBearerInvite(code: invite.code))
      return .none

    case .inviteFailed(let error):
      state.isInviting = false
      state.destination = .alert(.coBearerInviteFailed(message: Self.inviteMessage(for: error)))
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

  private func handleDelegateAction(
    state: inout State,
    action: DelegateAction
  ) -> Effect<Action> {
    switch action {
    case .finished, .closeRequested, .planRequested:
      return .none
    }
  }

  /// 서버처럼 코드포인트 수로 길이를 자른다. 이모지 하나가 글자 여러 개로 세어질 수 있다.
  static func prefix(_ text: String, scalars limit: Int) -> String {
    var view = String.UnicodeScalarView()
    view.append(contentsOf: text.unicodeScalars.prefix(limit))
    return String(view)
  }

  static func photoMessage(for error: BearerError) -> String {
    switch error {
    case .photoTooSmall: return "256×256보다 큰 사진을 골라 주세요"
    case .photoTooLarge: return "사진이 너무 커요. 다른 사진을 골라 주세요"
    case .unsupportedPhoto, .invalidRequest: return "이 사진은 올릴 수 없어요. JPEG·PNG·HEIC 사진을 골라 주세요"
    case .offline: return "인터넷에 연결되지 않아 사진을 올리지 못했어요"
    default: return "사진을 올리지 못했어요. 다시 골라 주세요"
    }
  }

  static func saveMessage(for error: BearerError) -> String {
    switch error {
    case .offline: return "인터넷에 연결되지 않았어요. 연결 후 다시 눌러 주세요"
    case .notBearer: return "이 깃발의 기수가 아니에요"
    case .zoneNotFound: return "고른 존을 찾을 수 없어요. 다른 존을 골라 주세요"
    case .termsRequired: return "새 약관에 동의한 뒤에 저장해 주세요"
    case .notAuthenticated: return "로그인한 뒤에 저장해 주세요"
    default: return "저장하지 못했어요. 잠시 후 다시 시도해 주세요"
    }
  }

  static func inviteMessage(for error: BearerError) -> String {
    switch error {
    case .notOwner: return "처음 깃발을 만든 기수만 초대할 수 있어요."
    case .coBearerFull: return "기수는 깃발마다 3명까지예요."
    case .offline: return "인터넷에 연결되지 않았어요."
    default: return "초대 코드를 만들지 못했어요. 잠시 후 다시 시도해 주세요."
    }
  }
}
