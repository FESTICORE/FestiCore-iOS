//
//  WebDelegate.swift
//  WebInterface
//
//  Created by FestiCore on 11/2/26.
//

import ComposableArchitecture

/// 앱 안 웹 화면이 부모에게 알리는 이동 계약
@CasePathable
public enum WebDelegate: Equatable, Sendable {
  case close
}
