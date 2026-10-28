import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCorePack",
  product: .framework,
  dependencies: [.core(.network), .core(.network, .interface)],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [.SPM.dependencies]
)
