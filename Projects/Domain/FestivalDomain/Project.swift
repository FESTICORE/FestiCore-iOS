import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestivalDomain",
  product: .framework,
  dependencies: [],
  hasInterface: true,
  interfaceDependencies: [.SPM.dependencies]
)
