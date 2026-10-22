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
private func run(_ executable: String, _ arguments: [String], environmentOverrides: [String: String] = [:]) -> Int32 {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = [executable] + arguments
  if !environmentOverrides.isEmpty {
    process.environment = ProcessInfo.processInfo.environment.merging(environmentOverrides) { _, new in new }
  }
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

private func tuist(_ arguments: [String], environmentOverrides: [String: String] = [:]) -> Int32 {
  run("mise", ["exec", "--", "tuist"] + arguments, environmentOverrides: environmentOverrides)
}

private var isCI: Bool {
  ["1", "true", "TRUE"].contains(ProcessInfo.processInfo.environment["CI"] ?? "")
    || ["1", "true", "TRUE"].contains(ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] ?? "")
}

private func cacheWarmArguments(_ arguments: [String]) -> [String] {
  if arguments.first == "print-hashes" { return ["cache"] + arguments }
  var forwarded = arguments.first == "warm" ? Array(arguments.dropFirst()) : arguments
  let hasProfile = forwarded.contains { $0 == "--cache-profile" || $0.hasPrefix("--cache-profile=") }
  let includeProjectTargets = forwarded.contains("--no-external-only")
  forwarded.removeAll { $0 == "--external-only" || $0 == "--no-external-only" }
  return ["cache", "warm"]
    + (hasProfile ? [] : ["--cache-profile", includeProjectTargets ? "all-possible" : "only-external"])
    + forwarded
}

private func setupCompilationCache() -> Int32 {
  guard !isCI else { return 0 }
  return tuist(["setup", "cache"])
}

private func warmBinaryCache(_ arguments: [String]) -> Int32 {
  guard !isCI, !arguments.contains("--no-binary-cache") else { return 0 }
  return tuist(cacheWarmArguments([]), environmentOverrides: ["TUIST_LOCAL_CACHE_ONLY": "true"])
}

private func generationArguments(_ arguments: [String]) -> [String] {
  var result = arguments
  if !result.contains("--no-binary-cache")
    && !result.contains(where: { $0 == "--cache-profile" || $0.hasPrefix("--cache-profile=") }) {
    result += ["--cache-profile", "only-external"]
  }
  return result
}

private func installAndGenerate(_ arguments: [String] = []) -> Int32 {
  let install = tuist(["install"] + arguments.filter { $0 != "--no-open" && $0 != "--no-binary-cache" })
  guard install == 0 else { return install }
  let setup = setupCompilationCache()
  guard setup == 0 else { return setup }
  let warm = warmBinaryCache(arguments)
  guard warm == 0 else { return warm }
  return tuist(["generate"] + generationArguments(
    arguments.filter { $0 == "--no-open" || $0 == "--no-binary-cache" }
  ))
}

private func module(_ arguments: [String]) -> Int32 {
  guard arguments.count == 2 else {
    fputs("사용법: ./make module <Feature|Domain|Data|Core|UI|Service> <Name>\n", stderr)
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
  let requiresFestiCorePrefix = ["Core", "UI", "Service"].contains(layer)
  guard ["Feature", "Domain", "Data", "Core", "UI", "Service"].contains(layer),
        name.range(of: "^[A-Z][A-Za-z0-9]*$", options: .regularExpression) != nil,
        (requiresFestiCorePrefix
          ? name.range(of: "^FestiCore[A-Z][A-Za-z0-9]*$", options: .regularExpression) != nil
          : !name.hasPrefix("FestiCore")),
        !reservedNames.contains(name) else {
    fputs("레이어 또는 이름이 올바르지 않습니다. Core/UI/Service에는 FestiCore 접두어가 필요합니다.\n", stderr)
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
  let catalogName = requiresFestiCorePrefix ? String(name.dropFirst("FestiCore".count)) : name
  let caseName = catalogName.prefix(1).lowercased() + catalogName.dropFirst()
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
  status = install == 0 ? installAndGenerate(forwarded) : install
case "install":
  status = installAndGenerate(forwarded)
case "generate":
  status = tuist(["generate"] + generationArguments(forwarded))
case "cache":
  status = tuist(cacheWarmArguments(forwarded))
case "cache:setup":
  status = tuist(["setup", "cache"] + forwarded)
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
  ./make setup                 mise 설치, 의존성·로컬 Tuist 캐시 준비, 프로젝트 생성
  ./make install               의존성·로컬 Tuist 캐시 준비, 프로젝트 생성
  ./make generate              준비된 캐시로 FestiCore.xcworkspace 생성
  ./make cache                 외부 모듈 바이너리 캐시 준비
  ./make cache:setup           Xcode Compilation Cache 설정
  ./make build                 Stage 시뮬레이터 빌드
  ./make test                  Stage 시뮬레이터 테스트
  ./make module <Layer> <Name> Feature/Domain/Data 또는 FestiCore 접두어가 있는 Core/UI/Service 모듈 생성
  ./make clean                 Tuist 생성물 정리
  """)
  status = 0
default:
  fputs("알 수 없는 명령: \(command)\n", stderr)
  status = 2
}
exit(status)
