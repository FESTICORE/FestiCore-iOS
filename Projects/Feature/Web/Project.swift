import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "Web",
  dependencies: [
    .service(
      .analytics,
      .interface
    ),
    .ui(.designSystem),
    .SPM.composableArchitecture
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.composableArchitecture
  ],
  hasDemo: true,
  demoDependencies: [
    .ui(.designSystem),
    .SPM.composableArchitecture
  ]
)
