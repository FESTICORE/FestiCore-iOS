//
//  Project+Environment.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import ProjectDescription

public extension Project {
  enum Environment {
    public static let appName = "FestiCore"
    public static let appStageName = "FestiCore-Stage"
    public static let appProdName = "FestiCore-Prod"
    public static let mainBundleId = "io.festiCore.co"
    public static let bundlePrefix = "io.festiCore.co"
    public static let appVersion = "0.1.0"
    public static let organizationTeamId = "N94CS4N6VR"
    public static let deploymentTarget: DeploymentTargets = .iOS("18.0")
    public static let deploymentDestination: Destinations = [.iPhone]
  }
}
