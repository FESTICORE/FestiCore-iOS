//
//  Project.swift
//  FestiCoreLiveActivity
//
//  Created by FestiCore on 10/23/26.
//

import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreLiveActivity",
  // 인터페이스로 조회하는 live 의존성이 정적 링크에서 제거되지 않도록 한다.
  product: .framework,
  dependencies: [
    .domain(.festival, .interface),
    .SPM.dependencies
  ],
  targetSettings: .settings(base: ["APPLICATION_EXTENSION_API_ONLY": "YES"]),
  hasTests: true
)
