# Point-Free 계열 라이브러리 성능 관점

`Tuist/Package.swift`에 Composable Architecture, Dependencies, Sharing, SQLiteData, StructuredQueries와 TCAFlow가 선언되어 있다. 현재 코드에 없는 Reducer·공유 상태·DB 쿼리에는 미리 최적화 규칙을 적용하지 않는다.

- TCA 기능이 생기면 불필요한 State 관찰, Effect 중복, 취소 식별자와 큰 트리의 갱신 범위를 측정한다.
- 공유 상태와 영속화가 생기면 저장 횟수·쿼리 범위·메인 액터 점유를 확인한다.
- 비동기 작업은 기능 수명과 함께 취소되는지 테스트한다.

선택한 API는 이 저장소의 설치 버전과 실제 코드에서 확인한다. 다른 프로젝트의 특정 버전 예시는 그대로 사용하지 않는다.
