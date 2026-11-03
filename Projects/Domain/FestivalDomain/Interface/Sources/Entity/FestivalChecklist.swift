//
//  FestivalChecklist.swift
//  FestivalDomainInterface
//
//  Created by FestiCore on 11/3/26.
//

/// 축제별로 기기에 저장하는 내 준비물 상태. 팩을 지워도 남는다.
public struct FestivalChecklist: Codable, Equatable, Sendable {
  public var checkedIDs: Set<String>
  /// 내가 추가한 항목
  public var customItems: [CustomItem]
  /// 목록에서 지운 팩 항목. 필수 항목은 지울 수 없다.
  public var hiddenIDs: Set<String>

  public init(checkedIDs: Set<String> = [], customItems: [CustomItem] = [], hiddenIDs: Set<String> = []) {
    self.checkedIDs = checkedIDs
    self.customItems = customItems
    self.hiddenIDs = hiddenIDs
  }

  public struct CustomItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
      self.id = id
      self.label = label
    }
  }
}
