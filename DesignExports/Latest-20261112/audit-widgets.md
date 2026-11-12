# 위젯·잠금화면 디자인 대조 · 2026-11-13

- 시안: 11-12 최신 사본(`FigmaBackups/FESTICORE-VPZzKIKZKruAKvKQTiQACx-20261112.fig`, git 미추적)을 풀어 낸 노드 값.
- 범위: `Widget · Components (사이즈별)`의 `Widget`(502:26197) 컴포넌트 31개(Small·Medium·Large·Live Activity·Lock Screen 각 6개, Lock Screen 틴트 예시 1개), `Widget Dev Spec`(482:22926) 1~9절, `Widget Matrix`(480:22926) 상태 7개, 잠금화면 Live Activity 시안 1 포스터형(469:22316)의 깃발·크루 아이콘.
- 다크: Dev Spec 5절이 `라이트/다크 상관없이 같은 고정 색이에요 (다크 클론 없음)`이라고 적었고 다크 컴포넌트가 없다. 앱 위젯도 `Static/Lime`·`Static/Ink`(`WidgetPalette.black` = #111113)·`Static/White` 고정색이라 시스템 모드와 관계없이 같은 색이다. 잠금화면 위젯은 시스템이 흑백(vibrant)·틴트로 바꾼다.
- 방법
  1. 사이즈·상태별 트리(크기·간격·패딩·글꼴·자간·기울기·색 변수·문구·아이콘)를 `FestiCoreFestivalWidget`·`FestiCoreFestivalActivityWidget`과 대조했다.
  2. 문구는 위젯 스냅샷(`FestivalWidgetSnapshot`: 공연 목록·저장 여부·귀가 시각·크루 이름)으로 만들 수 있는 것만 맞췄다.
- 최근 반영분 #525(마지막 날 종료 문구 `다음 페스티벌 보기`·축제 목록 딥링크, LA 종료 3시간 뒤 해제)와 #528(LA 색·여백)은 다시 고치지 않고 값만 확인했다.
- 글꼴: 위젯은 DesignKit 타이포 토큰이 아니라 `pretendardFontFamily(family:size:)`와 Bagel Fat One을 직접 쓴다. 잠금화면 사각형의 11 SemiBold는 `PretendardFontFamily.SemiBold`(기존 굵기, Pretendard Variable)로 시안 굵기 그대로 썼고 새 토큰은 만들지 않았다. 인라인은 시스템이 글꼴을 고정한다.

## 차이와 처리

| 프레임 | 노드 | 차이 | 처리 |
| --- | --- | --- | --- |
| 홈 S·M·L | Sparkle | 시안은 STAR(꼭짓점 4·안쪽 0.28) S 22·10, M 26·12·9, L 34·14를 오른쪽 위 정해진 자리에 둔다. 앱은 SF Symbol `sparkle` 하나 | 고침: 시안 도형 값으로 `WidgetSparkle` Shape를 그려 사이즈별 크기·위치에 둔다 |
| 홈 S | Body·Chip | 패딩 12/14/12/4·간격 6, 칩 `Static/Ink` r4 패딩 8/3·Bold 10 자간 4%·흰 글자, `NOW · {무대}`. 앱은 패딩 14/12·간격 8, 칩 없이 Bold 9 글자(팩 없음만 라임 글자 칩 -6° 기울임) | 고침: 모든 상태에 칩, 공연 중 `NOW · {무대}`, 패딩·간격 시안 값 |
| 홈 S | Bar | 좌우 12, 왼쪽 글자 다음 내 일정 아티스트(`NIGHT CORE`). 앱은 좌우 10, `다음 내 일정` | 고침 |
| 홈 M | Body | 패딩 14/12/14/4·간격 2, 상단 줄 `NOW PLAYING · {무대} · {시작}`·`LAST CALL · 종료 1시간 전`·`FESTICORE`, 서브 Bagel 14 -4° `@{무대}  {같은 무대 다음 공연}`·`@{무대}  첫 공연 {아티스트} {시각}`·`@{무대}  마지막 무대 {아티스트}`·`팩을 받으면 여기에 무대가 떠요`. 앱은 간격 6·아래 12, 상단 줄 축제 이름, 서브 `{머리말} · {무대}`, 팩 없음은 Pretendard 11 다른 문구 | 고침 |
| 홈 M | Bar | 라벨과 내용을 한 줄 Bold 11(`다음 내 일정  NIGHT CORE · 리벳 21:22`). 앱은 두 줄 | 고침 |
| 홈 L | Body·List | 패딩 16/16/16/8, 리스트 패딩 2/14·행 간격 10, 머리 Bold 10 자간 12% `Static Alpha/Black 60`(`NEXT`·`TODAY · 내 일정`·`TOMORROW · 내 일정`), 시각 Pretendard Black 11 폭 36, 무대 Bold 10 `Black 60`, 첫 행에 `Static/Ink` 알약(Bagel 12 라임 `N분 후`), 행 가운데 정렬. 앱은 머리 Medium 9, 시각 Medium 10, 무대 Medium 9, 알약 없음, 위 패딩 10 | 고침 |
| 홈 L | Bar | 좌우 16·간격 6·아이콘 13 + Bold 12 한 줄. 내 일정 없음 `plus` `내 일정을 넣으면 남은 시간을 알려 드려요`, 종료 후 `circle-check` `조심히 들어가요 · 팩은 오프라인으로도 볼 수 있어요`, 데이터 없음 `chevron-right` `탭하면 페스티벌 목록으로 가요`, 귀가 `route`. 앱은 좌우 14, 아이콘 없는 두 줄 | 고침: DesignKit `plus-16`·`circle-check-16`·`chevron-right-16`·`route-16`. 마지막 날 종료(#525 `다음 페스티벌 보기`)는 문구를 그대로 두고 아이콘을 붙이지 않았다 |
| 홈 L | 데이터 없음 안내 | `팩을 받으면 지금 무대 · 다음 내 일정 ·\n크루가 여기에 떠요.\n오프라인에서도 그대로 보여요.` `Black 60`. 앱은 크루 문구가 없고 검정 | 고침 |
| 잠금 원형 | Circular | 숫자 Bagel 26 + 단위 Bold 9(80%), 내 일정 없음 `NOW`(17)·`{무대}`, 데이터 없음 `F`·`팩 없음`. 앱은 Bagel 22 + Medium 9, 대신 `F`(25)·`FESTICORE` Medium 8 | 고침: 단위는 `.secondary` |
| 잠금 사각형 | Rectangular | 배경 20% r14·패딩 12/8, 라벨 SemiBold 11(80%)·큰 글자 Bagel 20·보조 Medium 11(80%), 내 일정 없음 `지금 {무대}`, 데이터 없음 `FESTICORE`·`팩 없음`. 앱은 배경·패딩 없음, Medium 10 두 줄 | 고침: `AccessoryWidgetBackground` r14, 80% 줄은 `.secondary` |
| 잠금 인라인 | Inline | 데이터 없음 `FESTICORE · 팩을 받아 주세요`, 내 일정 없음 `{무대} · {아티스트} 공연 중`. 앱은 `페스티벌 고르기`·아티스트만 | 고침 |
| Lock Live Activity | 깃발·크루 아이콘 | 아이콘 세트 `flag`·`users`(size=16) 14pt `Static Alpha/Black 60`. 앱은 SF Symbol `flag.fill`·`person.2.fill` 9pt | 고침: DesignKit `flag-16`·`users-24` 벡터를 14×14 template으로 쓴다. 위젯 확장이 이미 DesignKit 번들(`.module`)에서 Pretendard를 등록해 쓰므로 같은 번들의 이미지도 읽는다. DesignKit에 `users-16`이 없어 `users-24`를 줄였다(시안 16·24 글리프 폭 비율 0.81·0.83) |
| 홈 M·L·LA | 정보 줄·하단 바 | 깃발 존(`호락호락 · 리벳 앞 왼쪽 · 슬램`), 크루 위치 수(`크루 3명 슬램존 · 1명 밥`), 셔틀·막차(`셔틀 23:40`·`막차 GTX-A 킨텍스역`), 개장 시각(`OPEN 15:00`·`15:00 개장`), `DAY N` 표기 | 남김: 위젯 스냅샷에 깃발 존·크루 위치·셔틀·개장 시각·축제 일차가 없다. 스냅샷과 앱 쓰기 경로를 늘리는 작업은 이번 범위 밖이라 해당 줄은 기존 문구(`귀가 시간`·`다음 내 일정` 등)로 둔다 |
| 홈 S·M 공연 전 | 히어로 | `오늘\n개장!`·`15:00 개장`. 앱은 `{첫 공연 시각} 공연 시작` | 남김: 개장 시각이 스냅샷에 없어 첫 공연 시각을 개장으로 바꿔 부르지 않았다 |
| 홈 S·M 내 일정 없음 | Bar | `다음 NIGHT CORE`·`이 무대 다음 …` + 시각 `21:22`. 앱은 `내 일정이 없어요`와 다음 공연 | 남김: 숫자 자리에 남은 시간 대신 시각을 두는 규칙이 Dev Spec 4절에 없다 |
| 잠금 원형 | 숫자·단위 | `12` + `분 후`. 앱은 시스템 상대 시각 `12분` + `후` | 남김: 위젯 타임라인은 공연 경계에서만 갱신되고 숫자는 시스템 상대 시각이 매초 바꾼다. 분 단위를 직접 쪼개면 숫자가 멈춘다 |
| 홈 L 데이터 없음 | 히어로 | Bagel 38. 앱은 44에 자동 축소 | 남김: `페스티벌 고르기`가 한 줄에 들어가도록 `minimumScaleFactor`가 줄여 보인다 |
| Dynamic Island | compact·minimal·expanded | Dev Spec 1절 `⚠ 이번 범위 밖 · 다음 단계` | 남김: 대조 대상이 아니다 |
| 홈 위젯 틴트·클리어·StandBy | 렌더링 모드 | Dev Spec 7절 `⚠ 미디자인`·`⚠ 확인 필요` | 남김: 히어로 `widgetAccentable`은 이미 있다 |

## 차이 없음으로 확인한 항목

- 크기·배경: S 158×158·M 338×158·L 338×354 `Static/Lime`(containerBackground, 모서리 시스템), 하단 바 `Static/Ink` 높이 S·M 34·L 44, 바 숫자 Bagel S 15·M 16 `Static/Lime`.
- 히어로: Bagel S 30(2줄)·M 34·L 44, 기울기 S·L -6°·M -4°, 상단 줄 Bold M 9·L 10 자간 10%.
- L 리스트 이름 Bagel 첫 행 24·나머지 18, 최대 4행.
- 탭 이동: S·M·L·잠금화면 → 축제 라이브 보드, 데이터 없음·마지막 날 종료 → 축제 목록(#525).
- Lock Live Activity(#528): 카드 `Static/Lime` r24, 좌우 16, 아래 띠 48 `Static/Ink`, `다음 내 일정` `Static Alpha/White 60`, 깃발·크루 줄 `Static Alpha/Black 60`, 남은 시간 24 `Static/Lime`. 종료 3시간 뒤 해제(#525).

## 앱에 캡처가 없는 상태

- 위젯 확장은 테스트 타깃이 없다. 이번 수정은 노드 값 대조와 위젯 확장 시뮬레이터 컴파일로 확인했고, 홈 화면·잠금화면에 올린 위젯 캡처는 찍지 않았다. 실기기 확인은 하지 않았다.
