---
name: tuist
description: FestiCore iOS 프로젝트를 Tuist로 다룰 때 사용한다. 새 모듈 만들기(./make module · tuist scaffold Module 템플릿), 모듈 의존 추가(DependencyPlugin 표기), 외부 SPM 의존성 추가(Tuist/Package.swift · DependencyPackagePlugin), 프로젝트 생성 · 빌드 · 테스트(./make), generate 오류 해결. Projects/**/Project.swift · Tuist.swift · Workspace.swift · Plugins를 고칠 때도 쓴다.
---

# tuist

FestiCore iOS 프로젝트는 Tuist로 생성한다. `.xcodeproj` · `.xcworkspace`는 생성물이다. 직접 고치거나 커밋하지 않는다.
규칙 원본: `.claude/docs/development-environment.md`, 구조: `.claude/docs/architecture.md`, Domain 구성: `.claude/docs/domain-modules.md`. 다르면 문서가 우선이다.

모든 명령은 저장소 루트에서 `./make`(`TuistTool.swift`)로 실행한다. Tuist는 `.mise.toml`의 고정 버전을 쓴다.

## 1. 새 모듈 만들기

```bash
./make module Feature Profile              # Projects/Feature/Profile
./make module Domain ProfileDomain         # Projects/Domain/ProfileDomain
./make module Core FestiCoreAnalytics      # Core · UI · Service는 FestiCore 접두어가 필요하다
./make generate
```

`Tuist/Templates/Module`이 `Project.swift` · `Sources/<이름>.swift` · `Tests/<이름>Tests.swift`를 만들고, `Plugins/DependencyPlugin/.../Modules.swift`의 `<계층>Module` enum에 case를 넣는다. 만든 뒤 할 일:

1. 들어간 case 이름이 기존 표기와 맞는지 확인한다(예: `case auth = "AuthDomain"`, `case storage = "FestiCoreStorage"`). 다르면 고친다.
2. Interface가 필요한 모듈(Domain · Feature · Core · Service)은 `Interface/Sources` 폴더를 만들고 `Project.swift`에 `hasInterface: true`, `interfaceDependencies`를 둔다. Domain 폴더 구성은 `domain-modules.md`와 Attendance `AttendanceDomain`을 대조한다.
3. 테스트 타깃을 `Projects/App/Tests/FestiCore.xctestplan`에 추가한다.
4. 조립 모듈(`FeatureAssembly` · `ServiceAssembly` · `CoreAssembly`)에 연결이 필요하면 함께 더한다.

다른 모듈의 `Project.swift`를 통째로 복사해서 모듈을 만들지 않는다.

## 2. 모듈 의존 추가

`Project.swift`의 `dependencies`에 DependencyPlugin 표기만 쓴다. 경로 문자열(`.project(target:path:)`)을 쓰지 않는다.

```swift
dependencies: [
  .domain(.auth, .interface),        // Feature → Domain Interface
  .service(.analytics, .interface),  // → Service Interface
  .feature(.web, .interface),        // Feature → 다른 Feature Interface
  .ui(.designSystem),                // 기본값은 .implementation
  .SPM.composableArchitecture,
]
```

의존 방향 규칙(`.claude/docs/architecture.md`, `.claude/scripts/check-boundaries`가 검사):

- Feature는 Domain 구현(`<X>Domain`) · `API` · `APIEndpoint` · `FestiCoreNetwork*` · `FestiCoreAuth*`를 의존하지 않는다. Domain은 `.interface`로만 받는다.
- 구현(`.implementation`) 연결은 조립 모듈(`FeatureAssembly` 등)에서 한다. App은 개별 Feature 구현을 import하지 않는다.
- `APIEndpoint`는 Domain · Auth Service에 의존하지 않는다.

## 3. 외부 SPM 의존성 추가

1. 먼저 `Tuist/Package.swift`와 관련 모듈에 이미 있는지 확인한다.
2. `Tuist/Package.swift`의 `dependencies`에 `exact:` 버전으로 추가한다. framework 종류가 필요하면 `productTypes`에 적는다.
3. `Plugins/DependencyPackagePlugin`에 `.SPM.<이름>` 표기를 추가한다.
4. `./make install` → `./make generate`

## 4. 생성 · 빌드 · 테스트

```bash
./make setup                                # 처음 한 번 (mise · 의존성 · 캐시 · 생성)
./make generate                             # 프로젝트 생성
./make build                                # Stage 시뮬레이터 빌드
./make test                                 # Stage 플랜 전체 테스트
./make test -only-testing:AuthDomainTests   # 모듈 하나만
.claude/scripts/verify                      # 바뀐 경로에 맞는 단계만 (커밋 전 필수)
```

검증 결과는 실행한 명령과 함께 PR 본문에 적는다. 검증 명령 뒤에 `| tail` 같은 파이프를 붙여 종료 코드를 가리지 않는다.

## 5. 자주 나는 오류

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| `Module 'X' not found` (Feature에서) | Interface 대신 구현을 import했거나 `Modules.swift`에 case가 없음 | `.domain(.x, .interface)` 표기와 case를 확인한다 |
| 생성된 프로젝트의 컴파일 캐시 연결 실패 | 공유 캐시 서비스가 설치되지 않음 | `development-environment.md`의 "Xcode 컴파일 캐시 전환" |
| 앱 호스트 테스트가 시작 전에 실패 | git 제외 파일 `Projects/App/Resources/GoogleService-Info.plist` 없음 | 원본 checkout에서 복사한다(`harness.md`) |
| 외부 패키지 해석 실패 | `Tuist/.build/checkouts`가 없거나 `Package.resolved`가 오래됨 | `./make install` |

## 하지 않는 것

- `.xcodeproj` · `.xcworkspace` · `Derived/` 커밋
- Project.swift에 경로 문자열 의존
- 자격 증명 · 로컬 설정을 추적 파일에 넣기
