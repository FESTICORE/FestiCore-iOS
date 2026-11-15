# 푸시와 딥링크

## 푸시

- 표시되는 푸시는 `mutable-content`로 `Projects/Extension/FestiCoreNotificationService`를 거쳐 내용 보강과 App Group 데이터 갱신을 한다. 지금 `Extension/NotificationService.swift`는 `contentHandler(request.content)`만 부르는 통과 구현이므로 보강과 App Group 갱신을 구현할 대상이다.
- 앱을 깨워 동기화할 때는 `content-available` 무음 푸시를 쓰고 앱의 원격 알림 처리 경로(`AppDelegate`)에서 처리한다.

## 딥링크

딥링크는 Picke-iOS 구조를 FestiCore 위치에 그대로 둔다.

| Picke | FestiCore |
| --- | --- |
| `Core/PickeCoreUtility/Sources/Deeplink/PickeDeeplink` | `Projects/Core/FestiCoreUtility/Sources/Deeplink/FestiCoreDeeplink` |
| `App/Sources/Deeplink/PendingDeeplinkStore` · `AppDeeplinkBridge` | `Projects/App/Sources/Deeplink/`의 같은 이름 |
| 대기 저장소의 `@Shared(.pendingDeeplink)` 키 `Core/PickeStorage/Interface/Shared/PendingDeeplinkSharedKey`(`PersistentSharedKey`) | `Projects/Core/FestiCoreStorage/Interface/Shared/PendingDeeplinkSharedKey` |
| URL 진입점 `App/Sources/Application/PickeApp`의 `onOpenURL`→`AppDeeplinkBridge.handleURL(url)` | `Projects/App/Sources/Application/FestiCoreApp`의 `onOpenURL`→`AppDeeplinkBridge.handleURL(url)` |
| 알림 탭을 받는 `App/Sources/Application/AppDelegate+Push` | `Projects/App/Sources/Application/AppDelegate+Push` |
| `AppReducer`의 딥링크 처리(`AppDeeplinkBridge.consumePending()`) | 루트 `AppCoordinator`(`Projects/App/Sources/Navigation/Main/AppCoordinator`)의 라우팅 |

- Picke 키의 `legacyData`는 이전 저장소 값을 넘기기 위한 것이므로, 대기 값을 영속 저장한 적이 없는 FestiCore 키에는 두지 않는다.
- 경로는 `FestiCoreDeeplink` enum 하나로 정의하고 파싱·대기·라우팅 책임을 나누며 경로별로 테스트한다.
- 이전 대상: App 전용 경로 enum인 `Projects/App/Sources/Navigation/Main/WidgetDeepLink.swift`는 `FestiCoreDeeplink`로 합치고, `FestiCoreApp.swift`의 `RootView`가 View 상태로 대기·라우팅하는 `@State private var pendingWidgetRoute: WidgetDeepLink?`와 `openPendingWidgetRouteIfReady()`는 대기를 `PendingDeeplinkStore`, URL 전달을 `AppDeeplinkBridge`, 홈 준비 후 꺼내 이동하기를 `AppCoordinator`로 옮긴다.
