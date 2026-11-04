import ComposableArchitecture
import Foundation

@Reducer
public struct FestivalSwitcherFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable {
    public struct Item: Equatable, Identifiable {
      public let id: String
      public let name: String
      public let subtitle: String
      public let thumbnailURL: URL?

      public init(
        id: String,
        name: String,
        subtitle: String,
        thumbnailURL: URL?
      ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
      }
    }

    public var festivals: [Item]
    public var selectedFestivalID: String?

    public init(
      festivals: [Item],
      selectedFestivalID: String?
    ) {
      self.festivals = festivals
      self.selectedFestivalID = selectedFestivalID
    }
  }

  @CasePathable
  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(Delegate)
  }

  // MARK: - View

  @CasePathable
  public enum View: Equatable {
    case festivalTapped(String)
    case allFestivalsTapped
  }

  // MARK: - Delegate

  @CasePathable
  public enum Delegate: Equatable {
    case festivalSelected(String)
    case seeAllFestivals
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(
          state: &state,
          action: viewAction
        )
      case .delegate:
        return .none
      }
    }
  }
}

private extension FestivalSwitcherFeature {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .festivalTapped(id):
      guard state.festivals.contains(where: { $0.id == id }) else { return .none }
      return .send(.delegate(.festivalSelected(id)))
    case .allFestivalsTapped:
      return .send(.delegate(.seeAllFestivals))
    }
  }
}
