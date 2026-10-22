//
//  Tuist.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

let tuist = Tuist(
  project: .tuist(
    plugins: [
      .local(path: .relativeToRoot("Plugins/ProjectTemplatePlugin")),
      .local(path: .relativeToRoot("Plugins/DependencyPlugin")),
      .local(path: .relativeToRoot("Plugins/DependencyPackagePlugin"))
    ]
  )
)
