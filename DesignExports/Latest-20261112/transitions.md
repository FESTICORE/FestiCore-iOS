# 화면 전환 대조 · Figma 프로토타입 연결 · 2026-11-12

- 원본: 로컬 사본 `FigmaBackups/FESTICORE-VPZzKIKZKruAKvKQTiQACx-20261112.fig`(git 미추적)의 `canvas.fig`. `S13-S15-20261112/README.md`의 방법(zstd·kiwi-schema)으로 풀었다.
- 범위: Design 페이지(13:2340)의 모든 노드와 인스턴스 오버라이드(`symbolData.symbolOverrides`)의 `prototypeInteractions`. 다크 프레임은 라이트와 같은 연결이라 표에서 뺐다.
- 결과 요약: 연결 액션은 모두 `NAVIGATE`(이동) 또는 `BACK`(Top Bar 뒤로)이다. `OVERLAY`·`SWAP`·`SCROLL_TO`는 없다. 전환 종류는 `DISSOLVE`(0.25초)·`MOVE_FROM_RIGHT`(밀어 넣기)·`SMART_ANIMATE`·`INSTANT_TRANSITION`(탭바)이다.
- 시안의 바텀시트(로그인 시트·정렬 메뉴·공연 시트·페스티벌 전환)는 `OVERLAY`가 아니라 시트가 그려진 프레임으로 `SMART_ANIMATE` 이동한다. 앱은 이 화면을 `fcModal`로 둔다.
- `S14 C·D·E`와 `More → S10`은 `DISSOLVE`로 연결돼 있다. 사용자 요청(가입 흐름 한 스택, 마이 기수 설정 push)에 따라 스택 push로 맞췄다.
- 일부 인스턴스는 컴포넌트 원본의 오래된 연결(예: 버튼 → `S15 - 2. 깃발`)을 그대로 물려받았다. 같은 화면의 직접 연결과 다르면 직접 연결을 따랐다.

## 바꾼 전환

| 시안 연결 | 시안 전환 | 이전 앱 | 지금 앱 |
| --- | --- | --- | --- |
| S14 B 가입 정보 → C 기수 여부 → D1 깃발 등록 → E1 저장 완료 | NAVIGATE · DISSOLVE, C의 Top Bar는 BACK | 가입은 `fcModal`(fraction 1) 안 스택, C~E는 그 위 `fullScreenCover`(`bearerEntry`) | 가입 시트 스택에 C·D를 push(`AuthCoordinator.SignUpFlow.bearer`). D 뒤로 → C, C 뒤로 → B. E는 D 화면의 저장 완료 상태 |
| More A·C '기수이신가요?' → S10/S14 D | NAVIGATE · DISSOLVE | `fullScreenCover`(`bearerEntry`) | 마이 스택 push(`ProfileCoordinator.State.bearer`), 탭바 숨김 |
| More D 내 깃발 줄 → S10 프로필 수정 · S09 기수 보드 | NAVIGATE · DISSOLVE | `fullScreenCover` | 마이 스택 push, 탭바 숨김 |
| (마이에서 연) 등록 '초대 코드가 있어요' → S13 F~I 코드 인증 → S10 → S09 | 연결 없음(같은 흐름) | `fullScreenCover` 안 push | 마이 스택에 이어 push |

## 유지한 전환

| 시안 연결 | 시안 전환 | 앱 | 판단 |
| --- | --- | --- | --- |
| S00 목록 페스티벌 카드·검색 결과 → S15-1 내 일정 고르기 → S15-2 깃발 → S15-3 준비물 | MOVE_FROM_RIGHT | `FestivalCoordinator` push(`prepSchedule`·`prepFlags`·`prepChecklist`) | 일치 |
| S15 Step Header·S15-3 완료 → S01 라이브 보드 | DISSOLVE | 준비 경로를 걷어 내고 라이브 보드로 돌아감 | 일치 |
| S01 Top Bar 알림 → S01-1 알림함, 알림함 BACK | MOVE_FROM_RIGHT · BACK | push · `goBack` | 일치 |
| S02 공연 줄 → S03 공연 상세 | SMART_ANIMATE(시트 프레임) | 타임테이블 공연 상세 `fcModal` | 시트라 `fcModal` 유지 |
| S01 다음 공연 카드·S05 계획 줄 → S03 G 공연 상세 | SMART_ANIMATE(시트 프레임) | 이번에 라이브 보드·깃발 상세의 공연 열기 경로는 확인하지 않음 | 시트 계열이라 바꾸지 않음 |
| S01 C 로그아웃 크루·팔로우 줄 → C-1·C-2 로그인 시트, S04 C·S05 I 로그인 시트 | SMART_ANIMATE(시트 프레임) | 로그인 `fcModal`(auto) | 일치 |
| S01 D 빈 카드 → S07 B 크루 만들기 | SMART_ANIMATE | `crewCreate` push | 연결은 있으나 전환이 push인지 알 수 없어 유지(애매 1) |
| S01 A4 페스티벌 전환 시트 | 시트 프레임 | 라이브 보드 `fcModal`(`festivalSwitcher`) | 일치 |
| S02 칩·S04 칩·S04 정렬 메뉴·S05 팔로우 토스트 | SMART_ANIMATE(같은 화면 상태) | 화면 안 상태 변경 | 일치 |
| 탭바 S01·S02·S04 | INSTANT_TRANSITION | `FCTabBar` 탭 전환 | 일치 |
| S04 깃발 → S05 깃발 상세, S05 BACK | MOVE_FROM_RIGHT · BACK | `FlagCoordinator` push · `goBack` | 일치 |
| S00 Top Bar 검색 → S00 검색, 검색 Top Bar → 목록 | MOVE_FROM_RIGHT · DISSOLVE | 목록 화면 안 검색 상태 | 검색은 별도 경로가 아니라 유지(애매 2) |
| S00 탭(전체·예매 완료) | SMART_ANIMATE | 목록 안 탭 상태 | 일치 |
| More 설정 버튼 → S13-0 설정 홈 → S13 A 알림·C 잠금화면·D 계정·J 화면 모드, S13-0 BACK | DISSOLVE · BACK | 마이 스택 push | 스택 화면이라 push 유지 |
| S14 A 첫 진입 로그인 → B 가입 정보 | DISSOLVE | 첫 진입 화면은 덮기, 가입은 `fcModal`(fraction 1) | 애매 3 |
| S14 로그인 시트·L2 → S14-2·B2 가입 정보 | MOVE_FROM_RIGHT | 로그인 `fcModal`(auto)이 가입 `fcModal`(fraction 1)로 바뀜 | 애매 4 |
| S14 A·D 'Skip'·'나중에' → S00 목록, E1 → S00 예매 완료, E2 → S00 | DISSOLVE | 첫 진입 닫기, 가입 시트 닫기(`dismissFlow`), 팩 받기는 라이브 탭 목록 | 일치 |
| S10 E 저장 완료 → S00 목록 | DISSOLVE | 코드 인증 흐름은 S10 저장 뒤 S09 기수 보드 push | 애매 5 |
| Splash → Onboarding1~4 → S14 A | AFTER_TIMEOUT · DISSOLVE | `AppCoordinator` 루트 enum 전환 | 일치 |

연결이 없는 화면은 지금 방식을 유지한다.

| 앱 전환 | 위치 | 비고 |
| --- | --- | --- |
| 라이브 보드 → S09 기수 보드 `presentCover` | `FestivalCoordinator` | 시안에 S01 → S09 연결 없음 |
| 라이브 보드 → S06 존 지도, S07 크루·S08 참여 push | `FestivalCoordinator` | 시안 연결 없음 |
| 예매 외부 링크 `fullScreenCover` | `FestivalView`(ticket) | 시안 연결 없음, 외부 웹 |
| 공연 상세·일정 선택·세트 목록 | `MainTabView` `fcModal`, `TimetableCoordinator` push | S02 → S03은 시트 프레임 이동이라 그대로 |
| 깃발 상세 신고 시트(S05 E) | `FestivalFlagDetailView` `fcModal` | 시트 프레임 |
| 기수 보드 시트·팝업, 등록·프로필 팝업 | `BearerBoardView`·`BearerRegisterView`·`BearerProfileView` `fcModal`·`fcAlert` | 시안 연결 없음 |
| 크루·크루 모으기·참여 확인 시트와 팝업 | `FestivalCrewView`·`FestivalCrewGatherView`·`FestivalCrewJoinView` | 시안 연결 없음 |
| 설정 계정 닉네임 시트, 잠금화면 시트, 팩 상세·알림함·설정 팝업 | Profile Feature `fcModal`·`fcAlert` | 시안 연결 없음 |
| 마이 팝업(로그아웃·탈퇴 확인) | `MainTabView` `fcAlert` | 시안 연결 없음 |
| 이전 확인·재시도 시트 | `AuthCoordinatorView` `fcModal` | 시안에 화면 없음 |

## 애매한 것

1. S01 D 빈 카드 → S07 B 크루 만들기: `SMART_ANIMATE`라 push인지 시트인지 정할 수 없다. 앱은 아래 고정 버튼이 있는 전체 화면 push로 둔다.
2. S00 검색: 시안은 `MOVE_FROM_RIGHT`로 별도 화면에 들어가고 `DISSOLVE`로 돌아온다. 앱은 목록 화면 안 검색 상태라 경로를 새로 만들지 않았다.
3. S14 A 첫 진입 → B 가입 정보: 시안은 같은 화면 흐름처럼 `DISSOLVE`로 넘긴다. 앱은 로그인 후 프로필 확인 결과로 가입 시트를 띄우므로 첫 진입 화면(덮기)과 가입 시트를 한 스택으로 합치지 않았다.
4. 로그인 시트 → 가입 정보 `MOVE_FROM_RIGHT`: 시안은 시트 안에서 밀어 넣는다. 앱은 같은 `fcModal`이 auto 높이에서 fraction 1로 바뀐다. 로그인 시트와 가입 정보를 한 스택으로 합치면 로그인 확정·세대 확인 흐름이 바뀌어 보류했다.
5. S10 E 저장 완료 → S00 목록: 시안은 저장 완료 뒤 목록으로 간다. 앱의 코드 인증 흐름(S13 F~I → S10)은 저장 뒤 S09 기수 보드를 push한다. 화면 동작이 바뀌어 이번 범위에서 유지했다.
6. S14 D → E: 시안은 별도 프레임이지만 앱은 D 화면의 저장 완료 상태로 그린다(`DISSOLVE`와 같은 교차 전환). push 단계는 B → C → D다.
