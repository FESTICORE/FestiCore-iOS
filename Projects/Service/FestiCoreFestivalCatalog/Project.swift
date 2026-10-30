import ProjectDescription
import ProjectTemplatePlugin
import DependencyPlugin
import DependencyPackagePlugin

let project = Project.makeModule(
  name: "FestiCoreFestivalCatalog",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .domain(.festival, .interface),
    .domain(.festival),
    .service(.device, .interface),
    .SPM.alamofire,
  ],
  hasTests: true,
  hasInterface: false
)
