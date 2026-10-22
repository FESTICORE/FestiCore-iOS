# Core·UI 공통 모듈 설계 (#3)

## 목표와 완료 조건

iOS 18.0의 FestiCore 앱에 Core(Logger, Network, Storage)와 UI(Animation, DesignSystem, SharedUI) 모듈을 먼저 구성한다. 각 모듈의 타깃·의존성·테스트가 Tuist Workspace와 Stage PR CI에 포함되고, 기능별 커밋 뒤 develop PR을 검증·병합한다. 디자인 토큰 자동 갱신은 별도 FestiCore-DesignSystem 이슈 #1에서 이어서 구현한다.

## 이름과 경계

- 경로와 타깃 이름은 Projects/Core/FestiCoreLogger, FestiCoreNetwork, FestiCoreStorage 및 Projects/UI/FestiCoreAnimation, FestiCoreDesignSystem, FestiCoreSharedUI를 쓴다. Core/UI 생성 명령은 `FestiCore` 접두어를 필수로 하고 Feature/Domain/Data는 기존 무접두어 규칙을 유지한다. 사용법·README·도움말도 같은 규칙으로 갱신한다.
- Logger는 OSLog 레벨·카테고리 API를 제공하고 민감한 값은 private로 기록한다.
- Network는 참고 앱의 Interface/Sources/Tests 구조와 호출 방식을 유지한다. Interface에는 Endpoint, DataRequest, UploadRequest, FileUploadRequest, Request/Upload/FileUpload Client, 인증 정책·Credential·Store·Refreshing, HTTP/전송/디코딩 오류와 Dependencies 주입 지점을 둔다. 구현에는 Alamofire 세션, 인증 인터셉터, 재시도, 요청 인코딩, 일반·멀티파트·원시 파일 업로드, 응답 처리, 이벤트 로깅, 팩토리를 둔다. 공개 API의 DDD 접두어는 FestiCore로 바꾼다. 서버 전용 URL과 오류 코드는 실제 FestiCore 계약 전까지 옮기지 않는다.
- Storage는 Interface와 구현을 나눈다. Keychain·공유 값 저장 계약과 팩토리를 제공한다. 앱별 데이터 마이그레이션은 넣지 않는다. Keychain 어댑터는 주입 가능하게 만들어 단위 테스트에서 메모리 더블을 쓴다. 실제 Keychain 검증은 `IntegrationTests/`의 별도 호스트 앱 타깃에서 수행하며, Stage 스킴의 `Tests/` 검색 대상에서는 제외한다. 호스트 앱·서명이 준비되지 않으면 PR 한계에 명시한다.
- Animation은 외부 Bundle과 리소스 이름을 받는 뷰 경계를 제공한다. 실제 리소스가 없으므로 빈 Resources glob을 만들지 않는다.
- DesignSystem은 `FESTICORE/FestiCore-DesignSystem`의 `e8a0aec50760526e20492f7d166752c4058dea21` 커밋에 있는 `tokens/color/atomic.json`, `tokens/color/semantic.light.json`, `tokens/color/semantic.dark.json`, `tokens/foundation.json`, `tokens/typography.json`, `tokens/$themes.json`을 출처로 삼는다. 원본 JSON을 `Projects/UI/FestiCoreDesignSystem/Tokens/`에 스냅샷으로 두고 출처 SHA를 문서화한다. `makeModule`의 `testResources` 옵션으로 JSON은 테스트 타깃에만 넣는다. `$themes.json`을 따라 light 트리는 atomic·foundation·typography·semantic.light, dark 트리는 atomic·foundation·typography·semantic.dark로 각각 구성한다. 한 트리 안의 중복 dotted path, `{...}` 별칭의 순환·미해결 참조는 실패 처리한다. 각 트리의 값은 대응하는 `.light`·`.dark` UIColor trait collection과 비교한다. dimension은 1px = 1pt, lineHeight는 fontSize × 배율(pt), SwiftUI lineSpacing은 그 값에서 fontSize를 뺀 근삿값, letterSpacing은 fontSize × em으로 변환해 tracking에 쓴다. 테스트는 17pt × 1.294 및 17pt × -0.026em 사례를 포함한다. Pretendard는 아직 번들되지 않았으므로 fontFamily를 메타데이터로 보존하고 렌더링에는 system font와 매핑된 weight를 쓴다. 테스트는 family, size, line height, weight, tracking을 확인하고 폰트 대체는 PR 한계에 적는다. 자동 생성 결과는 별도 저장소의 자동화가 검증된 다음 갱신한다. 없는 브랜드 이미지·폰트·GIF를 임의로 만들지 않는다.
- SharedUI는 DesignSystem·Animation을 이용하는 공통 조립 컴포넌트만 제공한다.

## Tuist 변경

Project.makeModule의 기본 동작은 Home과 동일하게 유지하고 product, resources, testResources, hasInterface, interfaceDependencies, hasDemo 선택지를 더한다. Network/Storage에는 Interface 타깃을, 리소스가 실제로 있는 UI 모듈에만 Resources를 적용한다. DependencyPlugin에 CoreModule/UIModule과 relativeToCore/relativeToUI 및 .core/.ui helper를 함께 추가한다. TuistTool의 Core/UI 레이어 허용과 FestiCore 접두어 규칙을 맞춘다. Scheme+Stage가 Core/UI의 Tests 폴더를 검색하게 하고, PR 커버리지는 실행 가능 라인이 0인 Interface 타깃을 0%로 표시하지 않는다.

## 커밋·검증 순서

1. Tuist 구조와 여섯 모듈 타깃을 만들고 generate를 확인한다. 커밋: Tuist 모듈 구조 #3.
2. Logger를 구현하고 테스트한다. 커밋: Logger #3.
3. Network의 Interface·구현·팩토리·주입·인증·업로드·오류와 테스트를 구현한다. 커밋: Network #3.
4. Storage 구현과 단위 테스트를 추가한다. 커밋: Storage #3.
5. UI 세 모듈의 기본 API·컴포넌트 테스트를 구현한다. 커밋: UI #3.
6. mise exec -- tuist generate --no-open, Stage 시뮬레이터 xcodebuild test, PR CI 커버리지, 추적 비밀 파일 검사, git diff --check를 확인한다. Network 사용 예제에는 send(_:as:), send(_:), sendResponse(_:), upload(_:)를 포함한다.
7. develop PR에 변경 목적·증거·한계를 기록하고 병합해 iOS 이슈 #3을 닫는다. 그 후 토큰 저장소의 자동화 PR과 iOS 갱신 연동을 진행한다.
8. 참고 저장소의 `AGENTS.md`, `docs/agent/git-workflow.md`, `.claude/settings.json`, `.claude/hooks/pre-commit-check.sh`를 검토해 현재 iOS 구조에 맞는 지침·AI 리뷰·커밋 검사만 반영한다. `.claude/settings.local.json`, `.claude/agent-memory/`, `*.lock`, `app-harness.config.json`과 앱별 에이전트 메모리는 복사하지 않고 `.gitignore`로 추적을 막는다. 오래된 기술 스택과 실행되지 않는 훅 규칙은 그대로 옮기지 않는다.

## 제약

API 응답 래퍼와 인증 정책은 참고 앱의 기본 동작을 유지하되, FestiCore 서버 계약과 다른 값은 붙이지 않는다. 외부 라이브러리는 기존 Alamofire, Dependencies, SQLiteData, SDWebImage 범위에서만 선택한다. Apple Team ID N94CS4N6VR과 번들 ID io.festiCore.co를 유지한다.
