# 앱 종료 상태의 Live Activity 시작

일반 알림 허용은 Live Activity 생성 동작이 아니다. 앱이 열려 있을 때는 `FestiCoreFestivalLiveActivity.start`를 호출하고, 앱이 실행 중이지 않을 때는 서버가 ActivityKit push-to-start 토큰으로 APNs `start` 이벤트를 보내야 한다.

## 두 푸시 경로

| 경로 | 처리 주체 | 용도 |
| --- | --- | --- |
| ActivityKit `liveactivity` 푸시 | iOS와 Live Activity Widget | 축제 활동 시작·갱신·종료 |
| `mutable-content: 1` 일반 알림 | Notification Service Extension | 일반 알림 내용을 표시 전에 가공 |

Notification Service Extension에서 ActivityKit 활동을 시작하지 않는다. 현재 확장은 일반 알림을 그대로 전달한다. 알림 문구나 첨부 파일 계약이 정해지면 이 확장에 처리 로직을 추가한다.

## 서버 연결 계약

1. 앱은 `FestiCoreFestivalLiveActivity.pushToStartTokenUpdates()`의 현재 토큰과 변경된 토큰을 기기 인증과 함께 서버에 등록해야 한다. 기존 `apnsToken`과 개별 활동의 `pushToken`은 다른 값이다.
2. 서버는 이전 시작 토큰을 교체하고, 사용자가 기능을 끄거나 기기 등록을 해제할 때 삭제해야 한다. 등록 API는 아직 정의되지 않았으므로 iOS는 임의의 엔드포인트에 토큰을 보내지 않는다.
3. 서버는 시작 토큰을 대상으로 `apns-push-type: liveactivity`, `apns-topic: io.festiCore.co.push-type.liveactivity`, `apns-priority: 5` 또는 `10`으로 APNs에 요청한다.
4. 시작 payload의 `aps`에는 `timestamp`, `event: start`, `content-state`, `attributes-type: FestiCoreFestivalActivityAttributes`, `attributes`, `alert`가 필요하다. iOS 18 이상에서 개별 갱신 토큰이 필요하면 `input-push-token: 1`을 추가한다.
5. 서버와 iOS는 `attributes`의 `festivalID`·`festivalName`, `content-state`의 `phase`·`startDate` JSON 타입과 날짜 표현을 합의해야 한다. 원격 생성 후에는 `activityUpdates`와 활동별 `pushTokenUpdates`를 통해 갱신 토큰을 서버에 등록한다.

## 검증 단계

- Tuist 생성과 iPhone Duo Stage 빌드에서 Notification Service Extension이 앱에 포함되는지 확인한다.
- 현재 Swift Testing은 로컬 `start`·`end`를 검증한다. 시작 토큰 수집과 서버 등록 계약 테스트는 API가 정해진 뒤 추가한다. 시뮬레이터의 로컬 화면 검증은 원격 푸시 증거와 구분한다.
- 서버 API와 서명이 준비되면 실기기에서 앱을 종료하고 APNs `start`를 보낸다. 잠금 화면 표시, 원격 `update`·`end`, 토큰 교체를 각각 확인한다.

Apple Developer에서 앱 ID `io.festiCore.co`의 Push Notifications 기능을 켜고 새 확장 앱 ID `io.festiCore.co.NotificationService`를 등록해야 한다. 이어서 `bundle exec fastlane ios provision_live_activity_signing force:true`로 앱·Live Activity·알림 확장의 Development/AppStore 프로파일을 한 번 재발급한다. GitHub Actions에서는 `iOS Preview` 수동 실행의 `provision_live_activity_profile`과 `force_regenerate_profiles`를 모두 켜면 같은 작업을 실행한다. 이 절차를 마치기 전에는 QA/TestFlight/릴리스 서명 빌드가 실패할 수 있다. 평소 실행에서는 `force:true`를 생략해 공유 프로파일을 불필요하게 갱신하지 않는다.

TestFlight QA는 Stage API를 쓰더라도 AppStore 서명이므로 APNs 환경은 production이다. 현재 시작 토큰 스트림은 서버 등록 API가 없어 호출자가 없으며, 실기기에서 원격 시작을 검증한 상태가 아니다.

관련 이슈: [iOS #58](https://github.com/FESTICORE/FestiCore-iOS/issues/58), [iOS #37](https://github.com/FESTICORE/FestiCore-iOS/issues/37), [Backend #152](https://github.com/FESTICORE/FestiCore-Backend/issues/152).

Apple 문서: [ActivityKit push notifications](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications), [Notification Service Extension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension).
