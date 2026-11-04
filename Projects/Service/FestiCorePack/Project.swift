import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCorePack",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .SPM.sqliteData
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.dependencies
  ]
)
