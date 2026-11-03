import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "UserNotificationDomain",
  product: .framework,
  dependencies: [
    .core(.network, .interface),
    .core(.utility),
    .service(.apiEndpoint),
    .service(.auth, .interface),
    .SPM.dependencies
  ],
  hasTests: true,
  hasInterface: true,
  interfaceDependencies: [
    .SPM.dependencies,
    .external(name: "IssueReporting")
  ]
)
