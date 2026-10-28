import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreFestivalCatalog",
  product: .framework,
  dependencies: [.core(.network, .interface), .SPM.alamofire],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [.SPM.dependencies]
)
