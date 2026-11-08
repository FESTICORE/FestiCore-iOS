import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCorePack",
  product: .framework,
  dependencies: [
    .core(
      .network,
      .interface
    ),
    .service(.apiEndpoint),
    .SPM.sqliteData
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.dependencies
  ]
)
