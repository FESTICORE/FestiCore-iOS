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

private func availableSimulatorDestination() -> String? {
  let process = Process()
  let output = Pipe()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = ["python3", "Scripts/select-ios-simulator.py"]
  process.standardOutput = output
  process.standardError = FileHandle.standardError
  do {
    try process.run()
    let destination = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    process.waitUntilExit()
    return process.terminationStatus == 0 && !destination.isEmpty ? destination : nil
  } catch {
    fputs("시뮬레이터 선택 실패: \(error)\n", stderr)
    return nil
  }
}

private func testFull(_ arguments: [String]) -> Int32 {
  guard let destination = availableSimulatorDestination() else { return 1 }
  return tuist([
    "test", "run", "FestiCore-Stage",
    "--test-plan", "FestiCore",
    "--configuration", "Stage",
    "--no-selective-testing",
    "--skip-quarantine",
    "--no-binary-cache",
    "--",
    "-destination", destination,
    "CODE_SIGNING_ALLOWED=NO"
  ] + arguments)
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

private func renderGraph(production: Bool, forwardedArguments: [String]) -> Int32 {
  let fileManager = FileManager.default
  let workDirectory = fileManager.temporaryDirectory
    .appendingPathComponent("festicore-graph-\(UUID().uuidString)")
  do {
    try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)
  } catch {
    fputs("그래프 작업 디렉터리 생성 실패: \(error)\n", stderr)
    return 1
  }
  defer { try? fileManager.removeItem(at: workDirectory) }

  var graphArguments = [
    "graph", "--no-open", "--skip-external-dependencies",
    "--format", "dot", "--output-path", workDirectory.path
  ]
  if production { graphArguments.append("--skip-test-targets") }
  let graphStatus = tuist(graphArguments + forwardedArguments)
  guard graphStatus == 0 else { return graphStatus }

  let dotURL = workDirectory.appendingPathComponent("graph.dot")
  guard let rawGraph = try? String(contentsOf: dotURL, encoding: .utf8) else {
    fputs("Tuist 그래프 파일을 읽지 못했습니다: \(dotURL.path)\n", stderr)
    return 1
  }

  // Project+Template의 hasDemo는 타깃 이름을 "\(name)Demo"로 생성한다.
  // 이 접미사와 단어 경계가 일치하는 DOT 노드 및 간선만 제외한다.
  let graph = rawGraph
    .split(separator: "\n", omittingEmptySubsequences: false)
    .filter { line in
      line.range(of: #"\b[A-Za-z0-9_]+Demo\b"#, options: .regularExpression) == nil
    }
    .joined(separator: "\n")
  let filteredURL = workDirectory.appendingPathComponent("filtered.dot")
  do {
    try graph.write(to: filteredURL, atomically: true, encoding: .utf8)
  } catch {
    fputs("그래프 파일 저장 실패: \(error)\n", stderr)
    return 1
  }

  let output = production
    ? "docs/architecture/module-graph-prod.png"
    : "docs/architecture/module-graph-all.png"
  do {
    try fileManager.createDirectory(
      atPath: (output as NSString).deletingLastPathComponent,
      withIntermediateDirectories: true
    )
  } catch {
    fputs("그래프 출력 디렉터리 생성 실패: \(error)\n", stderr)
    return 1
  }
  let renderStatus = run("dot", ["-Tpng", filteredURL.path, "-o", output])
  guard renderStatus == 0 else {
    fputs("Graphviz 렌더링 실패: `brew install graphviz`를 확인하세요.\n", stderr)
    return renderStatus
  }
  print("\(output) 생성 완료")
  return 0
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
  status = tuist(cacheWarmArguments(forwarded), environmentOverrides: ["TUIST_LOCAL_CACHE_ONLY": "true"])
case "cache:setup":
  status = tuist(["setup", "cache"] + forwarded)
case "build":
  status = run("xcodebuild", ["build", "-workspace", "FestiCore.xcworkspace", "-scheme", "FestiCore-Stage", "-configuration", "Stage", "-destination", "generic/platform=iOS Simulator", "CODE_SIGNING_ALLOWED=NO"] + forwarded)
case "test":
  status = testFull(forwarded)
case "clean":
  status = tuist(["clean"] + forwarded)
case "module":
  status = module(forwarded)
case "graph":
  status = renderGraph(production: false, forwardedArguments: forwarded)
case "graph:prod":
  status = renderGraph(production: true, forwardedArguments: forwarded)
case "help":
  print("""
  ./make setup                 mise 설치, 의존성·로컬 Tuist 캐시 준비, 프로젝트 생성
  ./make install               의존성·로컬 Tuist 캐시 준비, 프로젝트 생성
  ./make generate              준비된 캐시로 FestiCore.xcworkspace 생성
  ./make cache                 외부 모듈 바이너리 캐시 준비
  ./make cache:setup           Xcode Compilation Cache 설정
  ./make build                 Stage 시뮬레이터 빌드
  ./make test                  Stage 플랜 전체 테스트 (선택적 테스트 비활성화)
  ./make module <Layer> <Name> Feature/Domain/Data 또는 FestiCore 접두어가 있는 Core/UI/Service 모듈 생성
  ./make graph                 외부 패키지·Demo를 제외한 전체 모듈 그래프 생성
  ./make graph:prod            외부 패키지·Demo·Tests를 제외한 제품 모듈 그래프 생성
  ./make clean                 Tuist 생성물 정리
  """)
  status = 0
default:
  fputs("알 수 없는 명령: \(command)\n", stderr)
  status = 2
}
exit(status)
