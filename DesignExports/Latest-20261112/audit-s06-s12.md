# S06–S12 디자인 전수 대조 · 2026-11-13

- 시안: 11-12 최신 사본(`FigmaBackups/FESTICORE-VPZzKIKZKruAKvKQTiQACx-20261112.fig`, git 미추적)을 풀어 낸 노드 값.
- 범위: Design 페이지 S06 존 지도·S07 크루·S08 크루 참여 확인·S10 깃발 프로필·Pack(팩 상세·S11 가는 길·S12 준비물) 섹션의 화면 프레임 라이트 37개, 다크 37개와 S09 기수 보드(다크 고정) 10개(Dev Note 제외).
- 방법
  1. 라이트·다크 프레임을 이름으로 짝지어 트리 전체(크기·간격·패딩·글자 스타일·색 변수·문구·보임 여부·컴포넌트 덮어쓰기)를 비교했다. 37쌍 모두 구조가 같고, 다른 값은 토큰 dark 투명도(`Fill/Normal` 10% 142곳, `Material/Dimmer` 70% 5곳, `Fill/Strong` 20% 4곳, `Accent/Background/Blue` 10% 1곳)뿐이다. 모두 `FestiCoreSemanticColor` dark 값과 같다. 따라서 다크 전용 차이는 앱이 `Static/*`로 고정한 곳에서만 생긴다.
  2. 화면과 컴포넌트(SYMBOL)에서 쓰는 `Static/*`·`Inverse/*`·`Atomic/*`·`Accent/*` 변수를 뽑아 앱 코드의 고정 색과 대조했다.
  3. 시안 문구(텍스트·컴포넌트 문구 속성)를 앱 소스에서 찾아, 샘플 데이터가 아닌 고정 문구가 다른 곳을 찾았다.
  4. 화면 머리·카드·시트의 간격·패딩·크기를 앱 `Metric`과 대조했다.
- 최근 반영분(#508·#516·#517·#521·#522)은 다시 고치지 않고 값만 확인했다.

## 차이와 처리

| 프레임 | 노드 | 차이 | 처리 |
| --- | --- | --- | --- |
| S06 B·C·E (Dark) | Map Marker kind=flag·crew 이름표 | 이름표 `Background/Elevated`, 깃발 이름 `Primary/Normal`(다크 라임), 크루 이름 `Label/Normal`. 앱은 Static/White 바탕에 Static/Ink 글자라 다크에서 흰 이름표가 떴다 | 고침: `FestivalZoneMapMarker` 이름표 색 |
| S06 B·C | Map Marker kind=flag-small | 24×24, 테두리·아이콘 `Background/Normal`. 앱은 28, Static/White 테두리·아이콘(다크에서 흰 테두리) | 고침: 크기 24, 테두리·아이콘 Background/Normal |
| S06 B·C | Map Marker kind=flag | 원 36, 원과 이름표 사이 8. 앱은 40·6 | 고침 |
| S06 C (Dark) | Map Marker kind=count `+3` | 28, `Inverse/Background` 원·`Inverse/Label` 글자·`Background/Elevated` 테두리. 앱은 32, Static/Ink·Static/White라 다크에서 반대로 보였다 | 고침: `FestivalZoneMapCluster` |
| S06 A·G·J | Map Legend | 좌우 패딩 10, 글자 Caption 1 Regular. 앱은 12·Medium | 고침 |
| S06 B~E | Zone Header Text | 이름·메타 사이 2. 앱은 4 | 고침 |
| S08 A~E | Footer | 채우기 없음(화면 Background/Normal), 위 테두리만. 앱은 Background/Elevated | 고침 |
| S08 E 로그인 필요 | Login Sheet | `크루에 들어가려면 로그인이 필요해요` / `로그인하면 바로 {크루}에 들어가요.\n크루원끼리만 서로의 존과 상태를 볼 수 있어요.` 앱은 라이브 보드용 `크루와 함께 보려면…` 문구 | 고침: 로그인 문맥 `crewJoin(crewName:)`을 더하고 참여 화면 로그인 요청을 이 문맥으로 올린다 |
| S10 A~E | 화면 배경 | `Background/Elevated`. 앱은 Background/Normal | 고침: `BearerProfileView` 배경 |
| Pack B·C·H | 반입 금지 Tags | 태그 간격 6. 앱은 4 | 고침: `PackRuleTags` |
| S07 E "모여!" 존 고르기 | Bearer Choice Sheet type=zone | 기수 존 시트 재사용: `어디로 모일까요?`(Title 2 Bold) / `누르면 바로 크루원 N명에게 소리 알림이 가요`, 2열 Choice Tile, 존을 누르면 바로 전송. 앱은 `모일 존을 선택해 주세요` 목록 + `모여!` 버튼 | 남김: 타일(`BearerChoiceTile`)이 Bearer 모듈 안에 있어 DesignKit으로 옮겨야 하고, 누르면 바로 보내도록 리듀서·테스트를 바꿔야 한다. 문구만 바꾸면 "누르면 바로"와 실제 동작이 어긋난다 |
| S07 A~H | 요약 `4명 · 11/22(일) 자정까지 유지` | 앱은 `마지막 날 종료 + 24시간`을 `M/d(E) HH:mm까지 유지`로 쓴다 | 남김: 크루 유지 시각 규칙(마지막 날 자정 vs 종료 후 24시간)이 정해지지 않았다. 문구만 바꾸면 실제 보관 시각과 어긋난다 |
| Pack D·E 팩 관리 | 안내 문구 | `페스티벌이 끝나고 30일 뒤에 자동으로 삭제돼요. …` 앱은 `팩을 지워도 내 일정과 체크한 준비물은 남아 있어요.` | 남김: 팩 자동 삭제(종료 30일 뒤)가 구현되지 않았다. 없는 동작을 안내하지 않는다 |
| S09 B 존 고르기 시트 | Head 제목 | `Label/Normal`. 앱은 Label/Strong | 같음(다크 고정 화면에서 두 토큰 dark 값이 #FFFFFF로 같다) |

## 차이 없음으로 확인한 항목

- S06: 존 이름표 기본 Fill/Normal·Label/Normal, 선택 Static/Lime·Static/Ink 1.5, 무대 태그 Inverse, 크루 마커 Atomic 100/700, 흐린 마커 40%·크루 줄 60%, 존 카드 패딩 16/16/16/8·간격 4·모서리 20, 빈 존·오래된 위치 안내 문구, 오프라인 배지, 지도 없는 팩 존 목록.
- S07: 모여 배너 Static/Lime·Static/Ink(#521), 내 상태 버튼 선택 Inverse, 크루 만들기 안내 `· 최대 12명 · 페스티벌마다 크루 1개`, 쿨다운 `모여! · N분 뒤 다시 가능`, 종료 후 `에 끝남`, 초대 안내 문구.
- S08: 아바타 52·겹침 14·테두리 Background/Normal 3, 초대 문구, 정원 초과 오류, 다른 크루 확인 팝업 문구, 닫기 버튼.
- S09: 다크 고정, 큰 버튼 선택 Inverse, 체크 오버레이 Black 80, 딤 Black 60.
- S10: 제목·안내 문구, 섹션 간격 28·묶음 간격 12, 존 안내 문구, 오늘 계획 카드 테두리, 저장 완료 미리보기(#508).
- Pack: 지도 앱 없음 `웹 ↗`(#517), 준비물 완료 `N개 모두 챙겼어요 · 준비 끝!`(#516), 새 버전 `v12 (새 버전 v13)`, 바뀐 내용, 팩 삭제 확인 제목.

## 앱에 캡처가 없는 상태

- 이번 수정은 노드 값 대조로 확인했다. 기존 캡처 테스트(`ZoneMapVisualCaptureTests`, `CrewVisualCaptureTests`, `BearerProfileVisualCaptureTests`, `PackDetailVisualCaptureTests`)는 검증 단계에서 그대로 실행했고 캡처 라이트 상태는 더하지 않았다.
