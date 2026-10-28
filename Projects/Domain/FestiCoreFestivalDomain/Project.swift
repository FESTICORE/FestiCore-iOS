import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreFestivalDomain",
  product: .framework,
  dependencies: [],
  hasInterface: true,
  interfaceDependencies: [.SPM.dependencies]
)
