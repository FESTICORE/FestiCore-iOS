//
//  TuistTool.swift
//  FestiCore
//
//  Created by FestiCore on 10/22/26.
//

import Foundation

private let arguments = Array(CommandLine.arguments.dropFirst())
private let command = arguments.first ?? "help"
private let forwarded = Array(arguments.dropFirst())

@discardableResult
private func run(_ executable: String, _ arguments: [String]) -> Int32 {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = [executable] + arguments
  process.standardInput = FileHandle.standardInput
  process.standardOutput = FileHandle.standardOutput
  process.standardError = FileHandle.standardError
  do {
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
  } catch {
    fputs("명령 실행 실패: \(error)\n", stderr)
    return 1
  }
}

private func tuist(_ arguments: [String]) -> Int32 {
  run("mise", ["exec", "--", "tuist"] + arguments)
}

private func module(_ arguments: [String]) -> Int32 {
  guard arguments.count == 2 else {
    fputs("사용법: ./make module <Feature|Domain|Data> <Name>\n", stderr)
    return 2
  }
  let layer = arguments[0]
  let name = arguments[1]
  let reservedNames: Set<String> = [
    "Any", "As", "Associatedtype", "Break", "Case", "Catch", "Class", "Continue", "Default",
    "Defer", "Deinit", "Do", "Else", "Enum", "Extension", "Fallthrough", "False", "Fileprivate",
    "For", "Func", "Guard", "If", "Import", "In", "Init", "Inout", "Internal", "Is", "Let",
    "Nil", "Operator", "Private", "Protocol", "Public", "Repeat", "Rethrows", "Return", "Self",
    "Static", "Struct", "Subscript", "Super", "Switch", "Throw", "Throws", "True", "Try",
    "Typealias", "Var", "Where", "While", "Path", "RawValue", "AllCases"
  ]
  guard ["Feature", "Domain", "Data"].contains(layer),
        name.range(of: "^[A-Z][A-Za-z0-9]*$", options: .regularExpression) != nil,
        !name.hasPrefix("FestiCore"),
        !reservedNames.contains(name) else {
    fputs("레이어 또는 이름이 올바르지 않습니다. 모듈 이름에는 FestiCore 접두어를 쓰지 마세요.\n", stderr)
    return 2
  }
  let target = name
  let path = "Projects/\(layer)/\(target)"
  let catalogPath = "Plugins/DependencyPlugin/ProjectDescriptionHelpers/TargetDependency+Module/Modules.swift"
  let enumName = "\(layer)Module"
  let dependencyPath = "Plugins/DependencyPlugin/ProjectDescriptionHelpers/TargetDependency+Module/TargetDependency+Modules.swift"
  guard let catalog = try? String(contentsOfFile: catalogPath, encoding: .utf8),
        let dependencies = try? String(contentsOfFile: dependencyPath, encoding: .utf8) else {
    fputs("의존성 플러그인 파일을 읽지 못했습니다.\n", stderr)
    return 1
  }
  let caseName = name.prefix(1).lowercased() + name.dropFirst()
  guard !FileManager.default.fileExists(atPath: path),
        !catalog.contains("case \(caseName) ="),
        !catalog.contains("\"\(target)\"") else {
    fputs("이미 존재하는 모듈: \(path)\n", stderr)
    return 2
  }
  let scaffold = tuist(["scaffold", "Module", "--layer", layer, "--name", target, "--author", "FestiCore"])
  guard scaffold == 0 else {
    try? FileManager.default.removeItem(atPath: path)
    return scaffold
  }
  let anchor = "public enum \(enumName): String, CaseIterable {"
  let updated: String
  var updatedDependencies = dependencies
  if catalog.contains(anchor) {
    updated = catalog.replacingOccurrences(of: anchor, with: "\(anchor)\n  case \(caseName) = \"\(target)\"")
  } else {
    updated = catalog.trimmingCharacters(in: .newlines) + "\n\n" + """

    public enum \(enumName): String, CaseIterable {
      case \(caseName) = "\(target)"

      var path: Path { .relativeTo\(layer)(rawValue) }
    }
    """
    let method = """

    public extension TargetDependency {
      static func \(layer.lowercased())(_ module: \(enumName), _ target: ModuleTarget = .implementation) -> Self {
        moduleDependency(name: module.rawValue, path: module.path, target: target)
      }
    }
    """
    updatedDependencies = dependencies.trimmingCharacters(in: .newlines) + "\n\n" + method + "\n"
  }
  do {
    try updated.write(toFile: catalogPath, atomically: true, encoding: .utf8)
    try updatedDependencies.write(toFile: dependencyPath, atomically: true, encoding: .utf8)
  } catch {
    try? catalog.write(toFile: catalogPath, atomically: true, encoding: .utf8)
    try? dependencies.write(toFile: dependencyPath, atomically: true, encoding: .utf8)
    try? FileManager.default.removeItem(atPath: path)
    fputs("모듈 카탈로그 업데이트 실패: \(error)\n", stderr)
    return 1
  }
  let generated = tuist(["generate", "--no-open"])
  if generated != 0 {
    try? catalog.write(toFile: catalogPath, atomically: true, encoding: .utf8)
    try? dependencies.write(toFile: dependencyPath, atomically: true, encoding: .utf8)
    try? FileManager.default.removeItem(atPath: path)
  }
  return generated
}

private let status: Int32
switch command {
case "setup":
  let install = run("mise", ["install"])
  status = install == 0 ? tuist(["install"]) : install
case "install":
  status = tuist(["install"] + forwarded)
case "generate":
  status = tuist(["generate"] + (forwarded.isEmpty ? ["--no-open"] : forwarded))
case "build":
  status = run("xcodebuild", ["build", "-workspace", "FestiCore.xcworkspace", "-scheme", "FestiCore-Stage", "-configuration", "Stage", "-destination", "generic/platform=iOS Simulator", "CODE_SIGNING_ALLOWED=NO"] + forwarded)
case "test":
  status = run("xcodebuild", ["test", "-workspace", "FestiCore.xcworkspace", "-scheme", "FestiCore-Stage", "-configuration", "Stage", "-destination", "platform=iOS Simulator,name=iPhone 17 Pro", "CODE_SIGNING_ALLOWED=NO"] + forwarded)
case "clean":
  status = tuist(["clean"] + forwarded)
case "module":
  status = module(forwarded)
case "help":
  print("""
  ./make setup                 mise 설치 및 Tuist 의존성 설치
  ./make install               Tuist 의존성 설치
  ./make generate              FestiCore.xcworkspace 생성
  ./make build                 Stage 시뮬레이터 빌드
  ./make test                  Stage 시뮬레이터 테스트
  ./make module <Layer> <Name> Feature, Domain, Data 모듈 생성 (예: Feature/Home)
  ./make clean                 Tuist 생성물 정리
  """)
  status = 0
default:
  fputs("알 수 없는 명령: \(command)\n", stderr)
  status = 2
}
exit(status)
