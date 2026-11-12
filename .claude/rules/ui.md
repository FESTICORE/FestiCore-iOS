---
paths:
  - "Projects/UI/**"
  - "Projects/Widget/**"
---

# UI · Widget 경로 규칙

상세 문서: `docs/agent/swiftui-patterns.md`, `docs/agent/popup-modal-system.md`, `docs/agent/figma-design.md`

## Hard

- DesignSystem 토큰 원천은 `FestiCore-DesignSystem` 저장소다. iOS 모듈에 토큰을 복제하거나 직접 고치지 않는다.
- DesignKit · SharedUI 컴포넌트 이니셜라이저에는 필수 내용만 두고, 스타일 · 상태 · 옵션은 `public extension`의 `func x(_:) -> Self` 체이닝으로 둔다.
- View 타입 본문에는 저장 속성 · 초기화 · `body`만 두고 섹션 · 하위 뷰 · UI 헬퍼는 `private extension <View>`로 뺀다. 단일 조각은 `var …: some View`, 여러 View를 묶는 섹션은 `@ViewBuilder func`.
- 공용 UI 모듈로는 여러 화면이 실제로 공유하는 컴포넌트만 옮긴다.
- 확인 팝업은 SharedUI `Alert/`의 `fcAlert`, 바텀시트는 `Modal/`의 `fcModal`을 쓴다.

## Soft (기존 코드가 다르면 기존 코드를 따른다)

- 아직 이니셜라이저 옵션으로 남은 기존 컴포넌트는 본보기로 삼지 않는다(`docs/agent/swiftui-patterns.md`의 이전 대상).
- View 분리는 상태 전환 · TCA 액션 · 접근성 · 다크 모드를 바꾸지 않는 범위에서 한다.
