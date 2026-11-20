# 화면 전환 완료 체크리스트

완료 보고 전에 모두 확인한다. 해당하지 않는 줄은 "해당 없음"과 이유를 적고, 나머지는 증거(명령과 종료 코드, 파일 경로)를 적어 PR 본문에 옮긴다. 규칙 원본은 `.claude/docs/navigation.md`다.

## 매뉴얼

- [ ] 작업 중 받은 지적은 `navigation.md` · 이 스킬 · 이 체크리스트 중 원인이 된 곳에 반영했다
- [ ] 전환 위치(기능 안 · 기능 밖 · 앱 루트)를 PR 본문에 적었다

## 흐름

- [ ] 화면(Feature)이 `routes`나 다른 화면을 직접 바꾸지 않고 `delegate`로만 알린다. Feature View에서 `NavigationStack` · `fullScreenCover`로 상세 화면을 열지 않는다
- [ ] 새 화면이 `<X>Screen` 목록, `handleRoute(state:action:)` 분기, `<X>CoordinatorView` 그리기에 모두 들어갔다
- [ ] 경로 값은 id 같은 작은 값이다
- [ ] 화면 전체를 덮는 목적지만 `presentCover`를 쓰고, 뒤로 가기는 `goBack()`(destination 투영 흐름은 `destination.dismiss`)이다
- [ ] 기능 밖으로 나가는 이동은 Coordinator `delegate`로 부모가 정한다
- [ ] 계정이 바뀌면 닫아야 하는 화면은 `clearAccountData()`에서 경로를 정리한다
- [ ] 전환 방향이 `DesignExports/Latest-20261112/transitions.md`의 화면별 기준과 맞는다

## 테스트 · 실행

- [ ] 기능 안 이동은 `routes` 변화, 기능 밖은 부모 `delegate`, 앱 루트는 State case 전환을 테스트했다
- [ ] 뒤로 가기 · 탭바 표시 · 계정 변경 시 경로 정리를 확인했다(해당할 때)
- [ ] `.claude/scripts/verify`가 통과했다(종료 코드 0)
- [ ] 기기에서 이동을 확인했다면 캡처 · 녹화 파일을 지웠다
