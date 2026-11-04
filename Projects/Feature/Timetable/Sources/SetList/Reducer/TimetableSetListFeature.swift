import ComposableArchitecture
import Foundation
import TimetableDomainInterface

@Reducer
public struct TimetableSetListFeature {
  public init() {}

  public enum Mode: Equatable { case search, changes }

  @ObservableState
  public struct State: Equatable {
    public var mode: Mode
    public var days: [TimetableDay]
    public var query: String

    public init(
      mode: Mode,
      days: [TimetableDay],
      query: String = ""
    ) {
      self.mode = mode
      self.days = days
      self.query = query
    }

    public var results: [TimetableDay] {
      let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
      return days.compactMap { day in
        var result = day
        result.sets = day.sets.filter { set in
          if mode == .changes { return set.previousStart != nil }
          let stage = day.stages.first { $0.id == set.stageID }?.name ?? ""
          return query.isEmpty || set.artist.localizedCaseInsensitiveContains(query)
            || stage.localizedCaseInsensitiveContains(query)
        }
        return result.sets.isEmpty ? nil : result
      }
    }
  }

  public enum Action: ViewAction {
    case view(View)
    case delegate(Delegate)
  }

  @CasePathable
  public enum View {
    case queryChanged(String)
    case setTapped(String)
    case backTapped
  }

  @CasePathable
  public enum Delegate {
    case setSelected(String)
    case close
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(action):
        return handleViewAction(
          state: &state,
          action: action
        )
      case .delegate:
        return .none
      }
    }
  }
}

private extension TimetableSetListFeature {
  func handleViewAction(
    state: inout State,
    action: View
  ) -> Effect<Action> {
    switch action {
    case let .queryChanged(query):
      state.query = query
      return .none
    case let .setTapped(id):
      guard state.results.contains(where: { $0.sets.contains { $0.id == id } }) else { return .none }
      return .send(.delegate(.setSelected(id)))
    case .backTapped:
      return .send(.delegate(.close))
    }
  }
}
