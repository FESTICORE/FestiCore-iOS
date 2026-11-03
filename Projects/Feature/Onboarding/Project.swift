import DependencyPackagePlugin
import DependencyPlugin
import ProjectDescription
import ProjectTemplatePlugin

let project = Project.makeModule(
  name: "Onboarding",
  product: .framework,
  dependencies: [
    .ui(.designSystem),
    .SPM.composableArchitecture
  ],
  resources: ["Resources/**"],
  hasTests: true
)
