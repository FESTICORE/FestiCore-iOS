//
//  TargetDependency+Modules.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public enum ModuleTarget {
  case interface
  case implementation
  case testing
}

private func moduleDependency(name: String, path: Path, target: ModuleTarget) -> TargetDependency {
  switch target {
  case .interface: .project(target: "\(name)Interface", path: path)
  case .implementation: .project(target: name, path: path)
  case .testing: .project(target: "\(name)Testing", path: path)
  }
}

public extension TargetDependency {
  static func core(_ module: CoreModule, _ target: ModuleTarget = .implementation) -> Self {
    moduleDependency(name: module.rawValue, path: module.path, target: target)
  }

  static func ui(_ module: UIModule, _ target: ModuleTarget = .implementation) -> Self {
    moduleDependency(name: module.rawValue, path: module.path, target: target)
  }

  static func feature(_ module: FeatureModule, _ target: ModuleTarget = .implementation) -> Self {
    moduleDependency(name: module.rawValue, path: module.path, target: target)
  }

  static func service(_ module: ServiceModule, _ target: ModuleTarget = .implementation) -> Self {
    moduleDependency(name: module.rawValue, path: module.path, target: target)
  }

}
