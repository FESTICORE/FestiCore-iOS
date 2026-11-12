# S00–S05 디자인 전수 대조 · 2026-11-13

- 시안: 11-12 최신 사본(`FigmaBackups/FESTICORE-VPZzKIKZKruAKvKQTiQACx-20261112.fig`, git 미추적)을 풀어 낸 노드 값.
- 범위: Design 페이지 S00·S01·S02·S03·S04·S05 섹션의 화면 프레임 라이트 52개, 다크 52개(Dev Note·안내 글 제외).
- 방법
  1. 라이트·다크 프레임을 이름으로 짝지어 트리 전체(크기·간격·패딩·글자 스타일·색 변수·문구·보임 여부·이미지 해시·컴포넌트 덮어쓰기)를 비교했다. 다크 프레임은 `Color` 변수 세트를 Dark 모드로 둔 같은 구조이고, 차이는 아래 표의 것뿐이다. 이미지 해시는 모든 짝이 같다(다크 전용 이미지 없음).
  2. 다크에서 값이 달라지는 차이(투명도 포함)는 DesignKit 토큰의 dark 값(`FestiCoreSemanticColor`)과 맞춰 봤다. `Fill/Strong`(dark 20%)·`Fill/Normal`(10%)·`Accent/Background/*`(10%)·`Material/Dimmer`(라이트 50%, 다크 70%)는 토큰 dark 값과 같다.
  3. 화면에서 쓰는 컴포넌트(SYMBOL)마다 색 변수를 뽑아 DesignKit 컴포넌트의 토큰과 대조했다. 라이트·다크 값이 다른 변수(`Inverse/*`, `Accent/Foreground/*`, `Label/*`)를 `Static/*`로 고정하거나 반대로 쓴 곳을 찾았다.
  4. 시안 문구(텍스트·컴포넌트 문구 속성)를 앱 소스에서 찾아, 샘플 데이터가 아닌 고정 문구가 다른 곳을 찾았다.
- PNG 캡처 대신 노드 값을 기준으로 봤다. 캡처는 `FestivalS01VisualCaptureTests`에 귀가 카드 라이트(`S01-E-final-hour-light`, `S01-F-ended-light`)를 더했다.

## 차이와 처리

| 프레임 | 노드 | 차이 | 처리 |
| --- | --- | --- | --- |
| S01 E 종료 1시간 전 / F 종료 후 (라이트) | Home Card 165:295 (166:3079, 166:3333) | 카드 배경 `Inverse/Background`, 글자·아이콘 `Inverse/Label`, 버튼 `가는 길` accent(Static/Lime), `같이 귀가` secondary(Background/Elevated·Line/Strong). 앱은 모드와 상관없이 흰 카드(Static/White)·검정 글자·ink 버튼이라 라이트에서 반대로 보였다 | 고침: `FCHomeCard` 배경·글자를 Inverse 토큰으로, 라이트 버튼을 accent·secondary로 |
| S01 E / F (Dark) | Home Card 174:5857 등 덮어쓰기 | 다크는 버튼을 `Static/Ink`(글자 Static/White)와 `Static/White`(글자 Static/Ink, 테두리 `Line/Strong`)로 덮어씀. 앱 흰 버튼 테두리는 Static/Ink였다 | 고침: 다크에서 ink·inkOutline 유지, `FCButton` inkOutline 테두리를 `Line/Strong`으로(사용처는 귀가 카드뿐) |
| S00 목록 (XMF 마감 카드) | Festival Card status=ended (Ended Overlay) | 마감 카드 이미지 위 레이어 `Static Alpha/Black 40`. 앱은 Black 60 | 고침: `FCFestivalCard` 마감 레이어 40% |
| S00 목록 (Dark) | Festival Card status=ended (D-day Tag `마감`) | 태그 배경 `Atomic/Ink/500`(#8A8A93, 라이트·다크 같음). 앱은 `Label/Assistive`라 다크에서 #A9A9B1로 밝아짐 | 남김: 같은 값의 semantic 토큰이 없다. iOS에서 토큰을 만들지 않으므로 가장 가까운 `Label/Assistive`를 유지(라이트는 같은 값). DesignSystem 저장소에서 토큰을 정하면 바꾼다 |
| S02 C 시간표 변경 / S03 D | Set Block state=changed (Time) | 바뀐 시각 글자 `Accent/Foreground/Orange`. 앱은 `Accent/Point/Orange`라 라이트에서 #FF9A2E(시안 #A65000) | 고침: `FCSetBlock` 바뀐 시각 색 |
| S01 D-1 깃발 안내 숨기기 확인 | 173:4342 팝업 본문 | 첫 문장 뒤 줄바꿈(`\n`). 앱은 공백으로 이어 씀 | 고침: 알림 본문에 줄바꿈 |
| S01 B 시작 전 | Section Header `활성 깃발` | 오른쪽 문구 `도착 예정 순`(A·C·D·E·G는 `최근 업데이트 순`) | 남김: 개장 전 깃발을 도착 예정 순으로 정렬할 데이터·정렬 규칙이 없다. 문구만 바꾸면 실제 정렬과 어긋난다 |
| S00 검색 - 최근 검색어 (Dark) | Recent Keyword | `Fill/Strong` 다크 20% | 같음(토큰 dark 값) |
| S01·S02·S04·S05 (Dark) | Stage Row mine·Offline Badge·Segmented·Notification Row·Dimmer | 다크 투명도(10%·70%) | 같음(토큰 dark 값) |

## 차이 없음으로 확인한 항목

- S00: 안내 문구 두 줄, 카드 간격 16·패딩 16, 최근 검색·다가오는 페스티벌 머리 패딩(16/20/16/8), 검색 결과 D-day 태그 Inverse, 결과 없음.
- S01: 섹션 머리 문구(지금 / 다음 무대·팔로우한 깃발·활성 깃발), 크루 줄 stale 색(Label/Disable·Assistive), 다음 일정 카드 Static 색, 무대 줄 라임 태그·Live Badge, 알림함·선택 삭제 문구, 로그인 시트 문구.
- S02: 내 일정/겹치는 일정 개수 문구, 셋 블록 mine·overlap Static 색과 배지 모서리(4·8), 시간표 공개 전 문구.
- S03: 셋 시트 Relative 배지 Inverse, 겹침 경고 문구 형식.
- S04: 머리 문구, 칩 선택 Inverse, 정렬 메뉴, 깃발 카드 색.
- S05: 콘텐츠 간격 20·패딩 16/20/16/24, 오늘 계획 머리, 지금 카드 muted·오프라인 문구, 신고하기 글자, Flag Hero Static 색, 신고 시트.

## 앱에 캡처가 없는 상태

- S04 C 로그아웃 팔로우 로그인 시트·E 오프라인·F 오늘 종료·A-1 정렬 메뉴, S05 A-스크롤·I 로그인 필요: 앱 상태는 있으나 캡처 테스트가 없다. 노드 값 대조만 했다.
