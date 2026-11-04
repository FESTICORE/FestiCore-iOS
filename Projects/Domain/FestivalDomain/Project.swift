import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestivalDomain",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .core(.utility),
    .service(.pack, .interface),
    .service(.apiEndpoint),
    .service(.device, .interface),
    .service(.auth, .interface),
    .SPM.kingfisher,
    .SPM.dependencies,
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .service(.pack, .interface),
    .SPM.dependencies
  ]
)
