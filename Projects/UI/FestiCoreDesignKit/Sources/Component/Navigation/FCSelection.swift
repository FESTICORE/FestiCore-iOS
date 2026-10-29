//
//  FCSelection.swift
//  FestiCoreDesignKit
//
//  Created by FestiCore on 10/29/26.
//

/// Tab·Segmented가 같이 쓰는 선택 판정 규칙.
///
/// 범위 밖 selection은 어느 칸도 선택 표시하지 않고, 호출자 상태도 고치지 않는다.
enum FCSelection {
  static func isSelected(index: Int, selection: Int, count: Int) -> Bool {
    (0..<count).contains(selection) && index == selection
  }
}
