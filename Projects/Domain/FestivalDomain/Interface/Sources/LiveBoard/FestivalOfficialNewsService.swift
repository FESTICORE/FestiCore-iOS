//
//  FestivalOfficialNewsService.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/20/26.
//

import Dependencies
import Foundation

/// `GET /api/v1/festivals/{id}/instagram`으로 축제 공식 인스타그램 최근 게시물을 받는다.
public protocol FestivalOfficialNewsService: Sendable {
  func officialNews(for festivalID: String) async throws -> FestivalOfficialNews
}

public enum FestivalOfficialNewsServiceDependency: TestDependencyKey {
  /// 공식 소식은 라이브 보드의 보조 정보라, 등록하지 않은 테스트에서는 비어 있는 소식으로 둔다.
  public static var testValue: any FestivalOfficialNewsService { return EmptyFestivalOfficialNewsService() }
}

public extension DependencyValues {
  var festivalOfficialNewsService: any FestivalOfficialNewsService {
    get { return self[FestivalOfficialNewsServiceDependency.self] }
    set { self[FestivalOfficialNewsServiceDependency.self] = newValue }
  }
}

private struct EmptyFestivalOfficialNewsService: FestivalOfficialNewsService {
  func officialNews(for festivalID: String) async throws -> FestivalOfficialNews {
    return .unavailable
  }
}
