# iOS 화면(TCA) 완료 체크리스트

완료 보고 전에 모두 확인한다. 해당하지 않는 줄은 "해당 없음"과 이유를 적고, 나머지는 증거(명령과 종료 코드, 파일 경로)를 적어 PR 본문에 옮긴다. 규칙 원본은 `.claude/docs/ios-tca.md` · `.claude/docs/swiftui-patterns.md` · `.claude/rules/feature.md`다.

## 매뉴얼

- [ ] 동작이 바뀌면 소유 모듈 `.spec/<기능>.md`를 먼저 고쳤다(`spec-first`)
- [ ] 작업 중 받은 지적은 `ios-tca.md` · 이 스킬 · 이 체크리스트 중 원인이 된 곳에 반영했다

## 모듈 · 의존

- [ ] 새 Feature는 `./make module Feature <이름>`으로 만들었고, 다른 Feature · 부모가 볼 타입만 `Interface/Sources`에 있다
- [ ] Feature가 `<X>DomainInterface`의 UseCase와 시스템 의존성(`date` · `continuousClock` · `mainQueue` 등)만 `@Dependency`로 쓴다. Domain 구현 · `API` · `APIEndpoint` · Network · Auth를 import하지 않는다(`check-boundaries` 통과)
- [ ] Feature가 쓰는 공개 값 타입은 Domain `Interface/Sources/Entity`에 있다
- [ ] 구조와 주입 위치를 Attendance_iOS의 같은 역할 파일과 대조했다

## Reducer

- [ ] 화면 하나에 `@Reducer` 하나, 파일은 `Sources/<화면>/{Reducer,View,Components,Model}`에 있다
- [ ] 파일 순서가 `init` → `State` → `Action` → 액션별 enum → `@Dependency` → `body` → `extension`의 처리 함수다
- [ ] Action이 `view` · `async` · `inner` · `delegate`(필요하면 `binding` · `destination` · 자식 case)로 나뉘고 쓰지 않는 case가 없다
- [ ] `body`는 분기만 하고 처리는 `extension`의 `handle{종류}Action`에 있다
- [ ] `.run`은 async 핸들러에서 시작한다. view 핸들러는 중복 입력 가드와 상태 변경 뒤 `.send(.async(...))`로 넘긴다
- [ ] 다시 시작 · 취소될 수 있는 작업에 `CancelID`와 `cancellable(id:cancelInFlight:)`가 있고, 늦게 온 응답(다른 축제 · 계정 세대)을 버린다
- [ ] 부모에게는 `delegate`로 알리고 다음 화면을 직접 열지 않는다. 부모는 자식 `view` 액션으로 명령한다
- [ ] 유한한 단계 · 상호 배타적인 선택은 enum이다

## View

- [ ] 화면 View는 `@ViewAction(for:)`이고 store 하나만 받으며 `send(.x)`만 쓴다(`store.send` 없음, `check-swift-conventions.py`가 검사)
- [ ] 타입 본문에는 저장 속성 · 초기화 · `body`만 있고 섹션은 `private extension`에 있다
- [ ] 확인 팝업은 `fcAlert`, 바텀시트는 `fcModal`이다(`popup-modal-system.md`)
- [ ] 글꼴 · 색 · 간격 · 반경이 DesignKit 토큰이다. Figma에 없는 화면이면 쓴 토큰과 이유를 PR에 적었다
- [ ] 비동기 데이터는 로딩 · 실패 · 빈 상태를 나누고 공용 Skeleton을 쓴다
- [ ] 새 Swift 파일에 헤더가 있다(`.claude/scripts/file-header`)

## 테스트 · 실행

- [ ] spec 동작 규칙마다 그 규칙을 검증하는 Swift Testing + `TestStore` 테스트가 있다
- [ ] 상태 전이 · 실패 · 취소 · 재시도와 async 단계의 `receive`를 확인했다. 의존성은 `withDependencies`로 명시했다
- [ ] 계약(UseCase · 서비스 프로토콜)을 바꿨다면 테스트 대역 구현도 함께 고쳤다
- [ ] `.skip` · 빈 테스트 · 주석 처리한 단언이 없다
- [ ] `.claude/scripts/verify`가 통과했다(종료 코드 0)
- [ ] 실기기 확인이 남았으면 PR 본문에 남은 확인 항목으로 적었다

## 정리

- [ ] 확인용 임시 파일 · 측정 테스트 · 빌드 산출물을 지웠다(커밋하지 않았다)
