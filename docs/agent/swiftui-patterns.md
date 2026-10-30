# SwiftUI View 패턴

Attendance의 `AttendanceCheckView`처럼 타입 본문은 저장 속성, 초기화, `body`에 집중한다. 화면 섹션, 하위 뷰 빌더, UI 전용 계산 값과 액션 헬퍼는 같은 파일의 `private extension`으로 내린다. 실제 구조는 `Projects/Feature/Timetable/Sources/TimetableView.swift`의 `TimetableView`와 `private extension TimetableView`를 참고한다. Attendance의 `ProfileView`처럼 기존 테스트가 접근하는 내부 헬퍼가 있으면 일반 `extension`을 쓰고 비공개 멤버에 각각 `private`를 붙인다.

이 규칙은 앱·Feature·Widget 화면과 DesignKit·SharedUI 컴포넌트에 함께 적용한다. 외부에서 호출하는 체이닝 설정은 `public extension`에 유지한다.

- 한 번만 쓰는 화면 섹션은 같은 파일의 extension에 둔다. 별도 View 타입은 독립 상태·프리뷰가 있거나 화면 경계가 분명할 때 만든다. 여러 화면에서 실제로 재사용할 때만 공용 UI 모듈로 옮긴다.
- 단순한 View에는 빈 extension을 만들지 않는다. View 분리만 하는 PR은 상태 전환, TCA 액션, 레이아웃, 접근성 동작을 바꾸지 않는다.
- 공통 색·서체·치수는 DesignKit 토큰을 쓴다. 라이트·다크, Dynamic Type, 화면 너비 변화를 실제 화면에서 확인한다.
- 비동기 로딩은 공용 `FCSkeletonView`와 관련 화면의 Skeleton 컴포넌트로 표시한다. 실패와 빈 상태는 별도 메시지·재시도 동작으로 구분한다. 로딩이 아닌 nil 값을 무한 Skeleton으로 표시하지 않는다.
