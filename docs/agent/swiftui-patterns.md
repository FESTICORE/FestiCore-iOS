# SwiftUI 패턴

현재 화면은 `Projects/Feature/Home/Sources/FestiCoreHomeView.swift`에 있다. 데이터 입력을 초기화 인자로 받고 `body`는 표시 역할에 집중한다.

- 복잡한 화면에서는 의미 있는 하위 View로 분리한다. 추상화는 실제 재사용이 있을 때 추가한다.
- 접근성 레이블과 Dynamic Type, 다크 모드를 실제 화면에서 확인한다.
- 공통 색·서체·치수는 DesignSystem 토큰을 소스로 사용한다. 생성물이 준비되기 전에는 토큰 이름이나 수치를 임의로 문서화하지 않는다.
- 로딩·오류·빈 상태는 기능 요구 사항에 맞게 드러낸다.

화면별 View extension, Skeleton과 스타일 값은 실제 구현이 생긴 뒤 문서화한다.
