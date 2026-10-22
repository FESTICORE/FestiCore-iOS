//
//  Extension+String.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension String {
  static func mainBundleID() -> String { Project.Environment.mainBundleId }
  static func appBundleID(name: String) -> String { "\(Project.Environment.bundlePrefix).\(name)" }
}
