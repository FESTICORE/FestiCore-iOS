import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestivalDomain",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .SPM.kingfisher,
    .SPM.dependencies,
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.dependencies
  ]
)
