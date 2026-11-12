# S13–S15 디자인 전수 대조 · 2026-11-13

- 시안: 11-12 최신 사본(`FigmaBackups/FESTICORE-VPZzKIKZKruAKvKQTiQACx-20261112.fig`, git 미추적)을 풀어 낸 노드 값.
- 범위: Design 페이지 S13 설정(0 설정 홈·A~J), More 마이 A~D, S14 첫 진입·로그인·가입·기수 설정(A·B·C·D1·E1·L2·B2·C2·D2·E2), 이전 S14 로그인 시트·S14-2 가입 정보, S15 준비 1~3의 화면 프레임 라이트 30개, 다크 30개(Dev Note·Case Label 제외). Onboarding 1~4(다크 섹션 4개, 라이트 짝 없음), Lock 잠금화면 Live Activity 1개, Widget 상태별 Matrix·개발 전달 스펙 각 1개.
- 방법
  1. 라이트·다크 프레임을 이름으로 짝지어 트리 전체(크기·간격·패딩·글자 스타일·색 변수·문구·보임 여부·컴포넌트 덮어쓰기)를 비교했다. 30쌍 모두 구조가 같다. 다른 값은 토큰 dark 투명도(`Material/Dimmer` 70%, `Fill/Normal` 10%, `Fill/Strong` 20%, `Accent/Background/Lime`·`Orange` 10%)와 S14 A 반짝이(라이트 `Secondary/Normal`, 다크 `Static/White`)뿐이다. 반짝이는 `LoginView.DecorationTone.secondary`가 이미 나눠 그린다.
  2. 시안 문구(텍스트·컴포넌트 문구 속성)를 앱 소스에서 찾았다. 샘플 데이터와 숨김 노드(`알림 수신 동의`)를 빼면 모두 앱 문구나 형식 문자열과 같다.
  3. 화면 머리·그룹·카드·구분선·하단 바와 Live Activity 카드의 간격·패딩·색을 앱 코드와 대조했다.
- 최근 반영분(#509·#510·#513·#518·#519·#520·#522·#523·#524·#525)은 다시 고치지 않고 값만 확인했다. 가입 흐름 화면 전환(#520·#523)은 건드리지 않았다.

## 차이와 처리

| 프레임 | 노드 | 차이 | 처리 |
| --- | --- | --- | --- |
| More A~D, S13-0·A·B·D·J | Card › Divider | `Divider` 361 폭에 좌우 패딩 16, 선 345. 앱은 왼쪽만 16 안쪽이라 선이 카드 오른쪽 끝까지 닿았다 | 고침: `ProfileView`·`SettingsHomeView`·`NotificationSettingsView`·`AppearanceSettingsView`·`AccountSettingsView` 구분선 좌우 16 |
| S13 A·B·C·D·E·J | Tab Bar | 알림·잠금화면·계정·로그아웃 확인·화면 모드에 `Tab Bar`(tab=my)가 있고, E 로그아웃 확인은 딤(`Material/Dimmer`)이 탭바까지 덮는다. #524는 설정 홈만 탭바를 보이고 하위 화면은 숨긴다 | 남김: `fcAlert`·`fcModal`은 탭 화면 안의 overlay라 탭바를 덮지 못한다. 탭바만 보이게 하면 계정 로그아웃 확인·잠금화면 깃발 고르기에서 탭바가 딤 밖에 밝게 남는다. 딤을 창 단위로 올리거나 팝업 동안 탭바를 함께 어둡게 하는 규칙을 정한 뒤 바꾼다 |
| Lock Live Activity | `다음 내 일정` | `Static Alpha/White 60`. 앱은 Static/White 70% | 고침: `staticalphaWhite60` |
| Lock Live Activity | 깃발·크루 줄 | 아이콘·글자 `Static Alpha/Black 60`. 앱은 패널 글자색(Static/Ink 100%)을 그대로 썼다 | 고침: `companionLabel` 색 |
| Lock Live Activity | 카드 안 좌우 여백 | 글자·별·카운트다운 x=16, 오른쪽 16. 앱은 14 | 고침: 두 패널 좌우 16 |
| Lock Live Activity | 깃발·크루 아이콘 | 아이콘 세트 `flag`·`users` 14. 앱은 SF Symbol `flag.fill`·`person.2.fill` 9 | 남김: 위젯 확장에서 DesignKit 이미지 자산 번들을 읽는지 실기기로 확인하지 않았다. 크기만 바꾸면 SF Symbol 모양이 시안과 더 달라 보인다 |
| S15-1 | Bottom Bar | `Material/Glass` 20% + 배경 흐림. 앱은 `Background/Elevated` 불투명 | 남김: 화면 배경이 `Background/Elevated`라 겹쳐 보이는 색이 같고, 스크롤 내용이 바 아래로 들어가지 않아 흐림 효과가 드러나지 않는다 |
| Dynamic Island | compact·minimal·expanded | 개발 전달 스펙에 `⚠ 이번 범위 밖 · 다음 단계`로 적혀 있고, 이 사본에는 지시된 노드 `2007:22640`·`2007:22645`가 없다 | 남김: 대조할 최신 노드가 없다. 앱 구현(#413)은 그대로 둔다 |
| Widget 홈 Small·Medium·Large·잠금화면 | Widget Matrix·Dev Spec | 이번 묶음에서는 문구와 상태 판정 표만 읽었고 사이즈별 노드 값은 대조하지 못했다 | 남김: 다음 묶음에서 `Widget · Components (사이즈별)`(502:26197)과 `FestiCoreFestivalWidget` 값을 대조한다 |

## 차이 없음으로 확인한 항목

- More: Contents 패딩 16/8/16/24·그룹 간격 24, 그룹 제목 Footnote Bold·개수 Footnote Regular `Label/Assistive`(좌우 4), 카드 `Background/Elevated` r16, 로그인 카드(B)·빈 카드 `페스티벌 둘러보기`(C)·내 깃발 줄·기수 보드 열기·다른 페스티벌 깃발 만들기(D), 팩 줄 `새 버전이 있어요 · 시간표 N개 변경`.
- S13: 알림 그룹 문구·각주 3개, 기기 알림 꺼짐 배너, 잠금화면 각주 2개, 계정 삭제 각주·로그아웃 ghost M 하단 16, 로그아웃 확인 딤(라이트 50%·다크 70%), 기수 인증 코드 문구·`N:NN 뒤에 다시 입력할 수 있어요.`, 화면 모드 3줄·각주, 설정 홈 `FESTICORE v{버전}`.
- S14: 반짝이 라이트·다크 색, 로그인 시트 딤·그래버, 가입 정보 전체 동의·필수 약관 2개, 기수 여부 아이콘 상자 44 r22, D 존 안내 `당일 첫 상태를 올리기 전까지 이 존에 "예정"으로 보여요.`, E1 팩 받기 권유 문구.
- S15: Step 1 머리(Caption 1 Medium·Title 2 Bold·Subheadline Regular, 간격 8), 콘텐츠 간격 20·패딩 16, `N개 선택` 오른쪽 정렬 Footnote Bold, 무대 목록 테두리 `Line/Normal` r16, 하단 바 패딩 16/12/16/8·간격 8, `다음 · N개 선택`·`다음 · N개 팔로우`·`N개 중 M개 챙겼어요`.
- Onboarding 1: 건너뛰기 ghost M, Contents 간격 32·패딩 24/24/24/40, 제목 Title 1 Bold·설명 Body Regular 간격 12, 페이지 점 8·간격 8.
- Lock Live Activity: 카드 361×156 `Static/Lime` r24, 아래 띠 48 `Static/Ink`, `NOW PLAYING · {무대}` Bold 9, 제목 34, 다음 일정 Bold 13, 남은 시간 24 `Static/Lime`.

## 앱에 캡처가 없는 상태

- 이번 수정은 노드 값 대조로 확인했다. 캡처 테스트는 검증 단계(`.claude/scripts/verify`)에서 그대로 실행했고 캡처 상태는 더하지 않았다. Live Activity는 테스트 타깃이 없어 위젯 확장 컴파일로만 확인했다.
