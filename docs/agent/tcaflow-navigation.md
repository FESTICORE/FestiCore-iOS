# 화면 전환

`AppCoordinator`는 Splash, Onboarding, Home의 루트 전환을 enum 상태로 관리한다. 탭 안에서 다른 화면으로 이동할 때는 App 계층의 Coordinator가 `TCAFlowRouter` 경로를 소유한다. Feature의 View에서 `NavigationStack`이나 `fullScreenCover`로 상세 화면을 직접 열지 않는다.

`FestivalCoordinator`는 축제 목록을 루트로 두고 라이브 보드와 알림함을 `push`한다. 뒤로 가기는 경로를 `goBack()`으로 닫는다. 기수 보드처럼 화면 전체를 덮는 목적지만 `presentCover`를 사용한다.

타임테이블의 일정 선택 화면은 `TimetableCoordinator`가 `TimetableFeature.destination`을 경로로 투영해 `push`한다. 경로 상태를 따로 저장하지 않는다. 화면이 뒤로 이동하면 Router 액션을 기존 `destination.dismiss`로 전달해 자식 효과의 수명을 유지한다. `MainTabCoordinator`는 기존 `.timetable` 입력을 자식 Coordinator로 전달한다.

마이 화면은 `ProfileCoordinator` 안에서 `ProfileFeature`를 한 번만 조립한다. `MainTabCoordinator`의 계정 입력, 팝업, Router 액션은 모두 `.profileCoordinator`를 거치며 로그인·로그아웃 요청 같은 delegate만 부모로 전달한다. 상세 경로는 기존 `ProfileFeature.destination`에서 계산하고 뒤로 가기는 `destination.dismiss`로 처리한다.

가입 약관 웹은 `SignUpFlowCoordinator`가 가입 화면에서 `push`한다. 가입을 마치면 같은 가입 스택에 기수 여부(S14 C) → 깃발 등록(D, 저장 완료 E는 같은 화면 상태)을 이어 `push`한다. 마이에서 여는 기수 설정(S14 D·S13 F~I·S10·S09)은 `ProfileCoordinator` 스택에 `push`한다. 두 스택 모두 `BearerEntryCoordinator.State`를 갖고 경로를 이어 붙여 투영하며, 화면 액션은 `BearerEntryCoordinator`로 넘긴다. 기수 흐름은 전체 화면 덮기를 쓰지 않는다. 화면별 전환 기준은 `DesignExports/Latest-20261112/transitions.md`에 둔다. URL은 앱의 API 호스트와 백엔드 공개 법적 문서 경로 `/api/v1/legal/terms`, `/api/v1/legal/privacy`를 조합한다. 예매 외부 링크와 앱 안의 법적 문서는 서로 다른 전환 정책을 따른다.

새 화면 전환은 실제 경로 상태, 자식 액션 전달, 뒤로 가기, 탭바 표시, 계정 변경 시 경로 정리를 테스트한다.
