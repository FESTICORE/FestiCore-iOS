//
//  WebFeature.swift
//  Web
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture
import Foundation
import WebInterface

/// 약관처럼 앱 안에서 보여 줄 웹 문서 화면
@Reducer
public struct WebFeature {
  public init() {}

  @ObservableState
  public struct State: Equatable, Identifiable {
    public enum Phase: Equatable {
      case loading
      case loaded
      case failed
    }

    public let url: URL
    public let title: String
    /// 바뀔 때마다 웹뷰가 새로 로드한다. 콜백은 이 값을 함께 보내 이전 시도의 결과를 무시한다.
    public var loadID = 0
    public var phase: Phase = .loading

    public var id: URL { url }

    public init(url: URL, title: String) {
      self.url = url
      self.title = title
    }
  }

  public enum Action: ViewAction, Equatable {
    case view(View)
    case delegate(WebDelegate)
  }

  public enum View: Equatable {
    case onAppear
    case closeTapped
    case retryTapped
    case loadFinished(loadID: Int)
    case loadFailed(loadID: Int)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        guard state.loadID == 0 else { return .none }
        state.loadID = 1
        state.phase = .loading
        return .none

      case .view(.retryTapped):
        state.loadID += 1
        state.phase = .loading
        return .none

      case let .view(.loadFinished(loadID)):
        guard loadID == state.loadID else { return .none }
        state.phase = .loaded
        return .none

      case let .view(.loadFailed(loadID)):
        guard loadID == state.loadID else { return .none }
        state.phase = .failed
        return .none

      case .view(.closeTapped):
        return .send(.delegate(.close))

      case .delegate:
        return .none
      }
    }
  }
}
