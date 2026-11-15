---
name: screen-flow
description: FestiCore 화면 전환을 만들거나 고칠 때 사용한다. TCAFlow @FlowCoordinator(routes · router · delegate · handleRoute), 새 화면을 흐름에 추가, 기능 밖으로 나가는 이동(부모 delegate), 앱 루트 흐름 전환(AppCoordinator State enum), 계정 변경 시 경로 정리, 이동 테스트. Projects/App/Sources/Navigation의 Coordinator · CoordinatorView를 고칠 때 쓴다. 화면 하나의 내부는 tca-feature.
---

# 화면 전환 (TCAFlow)

규칙 원본: `.claude/docs/navigation.md`. 다르면 문서가 우선이다.
실제 예: `Projects/App/Sources/Navigation/Festival/FestivalCoordinator.swift` · `FestivalCoordinatorView.swift` · `Projects/App/Tests/Sources/FestivalNotificationInboxRoutingTests.swift`

원칙: 탭 · 기능마다 App 계층의 Coordinator 하나가 `routes`를 State로 갖는다. 화면은 무슨 일이 일어났는지만 알리고, 어디로 갈지는 Coordinator가 정한다. Feature의 View에서 `NavigationStack`이나 `fullScreenCover`로 상세 화면을 직접 열지 않는다.

| 항목 | 위치 |
| --- | --- |
| 화면 목록 | `extension <X>Coordinator { @Reducer enum <X>Screen }` |
| 스택 | `State.routes: [Route<<X>Screen.State>]` |
| 화면 → Coordinator | 자식 `view` · `delegate` → `handleRoute(state:action:)`의 `.router(.routeAction(id:action:))` 분기 |
| 기능 밖으로 | Coordinator `.delegate` → 부모 Coordinator |
| 이동 함수 | `push` · `presentCover` · `goBack` |

## 새 화면을 흐름에 넣기

1. 화면을 만든다(`tca-feature`). 다음 화면이 필요하면 자식에 `delegate` case를 하나 더한다.
2. 화면 목록에 더한다: `<X>Screen`에 `case notificationInbox(NotificationInboxFeature)`. 경로 값은 id 같은 작은 값만.
3. `handleRoute`에 분기를 더한다.
   ```swift
   case .router(.routeAction(id: _, action: .liveBoard(.delegate(.notificationInboxRequested)))):
     state.routes.push(.notificationInbox(.init()))
     return .none
   ```
4. `<X>CoordinatorView`의 화면 case 분기에 그리기를 더한다.
5. 계정이 바뀌면 닫아야 하는 화면이면 State의 `clearAccountData()`에서 경로를 정리한다.
6. 테스트를 더한다(아래).

## 확인할 것

- `@FlowCoordinator(screen:navigation:)`는 body를 만들고 `handleRoute(state:action:)`를 부른다. Coordinator에 `handleRoute`를 구현한다.
- 화면(Feature)이 `routes`나 다른 화면을 직접 바꾸지 않는다. 자식에 알릴 명령은 자식의 `view` 액션으로 보낸다.
- 화면 전체를 덮는 목적지(기수 보드 등)만 `presentCover`를 쓴다. 뒤로 가기는 `goBack()`.
- `destination`을 경로로 투영하는 흐름(`TimetableCoordinator` · `ProfileCoordinator`)은 경로 상태를 따로 저장하지 않고 뒤로 가기를 `destination.dismiss`로 전달한다.
- 화면별 전환 기준은 `DesignExports/Latest-20261112/transitions.md`에 있다.

## 앱 루트 흐름

`Projects/App/Sources/Navigation/Main/AppCoordinator.swift`: State가 흐름별 enum(`case splash` · `case home` 등)이고 `.ifCaseLet(\.splash, action: \.scope.splash)`로 자식을 붙인다. 흐름을 더할 때는 State case · Action case · `ifCaseLet` · `AppCoordinatorView`의 `store.state` 분기를 같이 더한다. 흐름 전환은 자식 `delegate`를 받아 State case를 바꾼다. 딥링크 라우팅은 `.claude/docs/push-deeplink.md`.

## 테스트

- `TestStore`로 자식 `delegate`를 보내고 `routes` 변화를 검증한다. 루트는 `AppCoordinatorTests`처럼 State case 전환을 본다.
- 실제 경로 상태, 자식 액션 전달, 뒤로 가기, 탭바 표시, 계정 변경 시 경로 정리를 확인한다.
- 앱 호스트 테스트는 루트 Store의 자동 시작 효과를 실행하지 않고 필요한 의존성을 명시적으로 주입한다.
