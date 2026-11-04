# Swift 코딩 규칙

## 현재 코드 기준

- 새 Swift 파일 헤더는 파일명, `FestiCore`, `Created by FestiCore` 형식을 따른다.
- 공개 API는 필요한 타입과 멤버에만 `public`을 붙인다. 모듈 간 접근은 매니페스트의 의존성 방향을 먼저 확인한다.
- Swift 6 동시성 경고를 무시하지 않는다. 공유 상태는 격리와 생명주기를 명확히 한다.
- 오류를 무조건 삼키거나 강제 언래핑하지 않는다. 에러 전파와 복구 지점을 호출자에게 명확하게 제공한다.
- 값을 반환하는 함수와 계산 프로퍼티는 `return`을 명시한다. 필요한 계산·검증을 먼저 하고 최종 결과를 아래에서 반환한다.
- 함수·이니셜라이저 선언에 파라미터가 2개 이상이면 여는 괄호 다음 줄부터 파라미터를 하나씩 각 줄에 작성한다. 0~1개면 한 줄도 허용한다. 제네릭 타입·클로저 안의 쉼표는 파라미터 수에 포함하지 않는다.
- 모듈과 테스트 대역에서 `fatalError`로 프로세스를 종료하지 않는다. 오류를 던질 수 있으면 호출자에게 전달하고, 던질 수 없으면 누락을 기록한 뒤 안전한 값을 반환한다.
- 테스트에는 현재 `Projects/App/Tests`의 Swift Testing 패턴을 참고하되, 실제 행동을 검증하는 독립적인 사례를 작성한다.

`try/catch` 금지나 특정 `Result` 변환식을 일반 규칙으로 강제하지 않는다. 구현 언어 규칙과 코드 경로를 확인해 적절한 오류 처리 방식을 선택한다.

## 변경 파일 검사

`.claude/hooks/check-swift-conventions.py`는 Swift 소스를 자동 수정하지 않고 명시적 `return`, 화면 View의 `@ViewAction`, Reducer의 `handleViewAction`, View 섹션의 `@ViewBuilder`, 함수·이니셜라이저 선언의 2개 이상 파라미터 줄바꿈 중 확실히 판별되는 형태만 검사한다. API·Domain·Feature·App의 Swift 파일에 동일하게 적용한다. 복잡한 분기와 클로저 안의 반환 흐름, State 변수의 의미별 묶음, 화면과 Reducer의 실제 1:1 관계는 정적 검사로 확정하지 않고 코드 리뷰에서 확인한다.

Claude Code는 저장소의 `PostToolUse` 훅과 커밋 전 훅을 사용한다. Codex는 `.codex/hooks.json`의 프로젝트 훅을 사용한다. 도구 훅과 별개로 `python3 .claude/hooks/check-swift-conventions.py <Swift 파일...>`로 직접 검사할 수 있다. Git 커밋 훅은 저장소에서 `git config core.hooksPath .githooks`를 설정하면 적용된다. 환경별 훅 동작과 별도로 커밋 전에는 검사 명령과 `git diff --check`를 직접 실행한다.
