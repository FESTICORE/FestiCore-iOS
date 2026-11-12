# Live Activity

`Projects/UI/FestiCoreLiveActivity`의 `FestiCoreFestivalLiveActivity`는 축제 활동의 시작, 상태 갱신, 종료와 원격 갱신용 push token 관찰 API를 제공합니다. 별도 `Projects/Widget/FestiCoreWidget` 프로젝트의 `FestiCoreLiveActivityExtension`은 잠금 화면과 Dynamic Island용 `ActivityConfiguration`을 선언합니다. 앱 Info.plist에는 `NSSupportsLiveActivities`가 설정되어 있고 App 타깃은 확장에 의존합니다.

축제 라이브 보드에서 사용자가 Live Activity를 켜거나 끌 수 있습니다. 버튼은 이미 활동 중이거나 같은 축제의 내 일정에 유효한 공연이 있을 때 표시됩니다. 프로필의 잠금화면 설정에서는 활동 목록을 확인하고 모두 끌 수 있습니다. 시작은 축제 첫날 2시간 전부터 마지막 날 종료 전까지 가능하며, ActivityKit이 약 8시간 후 활동을 종료하면 다시 켤 수 있습니다. 앱이 활성 상태인 동안 축제 시작·종료 경계와 카탈로그 변경에 맞춰 모든 진행 중인 축제 활동을 갱신합니다. 앱을 다시 열면 ActivityKit 목록에서 활동을 복원합니다. 앱이 실행되지 않을 때 정확한 시각에 갱신하거나 원격으로 시작하는 기능은 #58에서 추적합니다.

`YYYY-MM-DD` 일정은 서울 시간 그날 00:00부터 다음 날 00:00 전까지로 해석합니다. 오프셋을 포함한 ISO 8601 타임스탬프는 적힌 정확한 시각으로 해석하며 `lastDate`도 종료 시각입니다. 앱이 백그라운드에 있는 동안 그 시각을 지나면 잠금 화면 콘텐츠는 stale로 표시됩니다.

`Projects/Service/FestiCoreDevice`는 기기 등록과 `PUT/DELETE /api/v1/devices/live-activity` 요청을 제공합니다. 앱 시작 시 일반 기기 등록을 시도하고, 이 요청 body의 `liveActivityPushToStartToken`에 push-to-start 토큰을 함께 보냅니다(`AppDelegate+DeviceRegistration.swift`의 `observeLiveActivityStartToken`이 토큰 변경 시 다시 등록). 활동별 갱신 토큰은 `LiveActivityTokenSync`가 기기당 현재 활동 하나를 골라 `PUT /api/v1/devices/live-activity`로 등록하고, 활동이 없어지면 `DELETE`로 해제합니다. 서버가 이 토큰으로 APNs 갱신을 보내는 구현은 [Backend #152](https://github.com/FESTICORE/FestiCore-Backend/issues/152)에서 진행 중입니다.

현재 확인 범위와 남은 기기 검증은 #105에 기록합니다.

- 시작·갱신·종료 경로: 라이브 보드 켜기 → `FestivalLiveActivityClient.start`, 경계·카탈로그 변경 → `update`, 축제 종료 → `finish`(`endFinished`), 끄기 → `end`. `endFinished`는 완료 상태로 바꾸고 공연 종료 3시간 뒤(`dismissalPolicy: .after(end + 3h)`)에 내립니다. 종료 시각이 없으면 시스템 기본 정책을 씁니다.
- 자동 테스트: `FestiCoreLiveActivityTests`의 `FestivalActivityPayloadTests`(content-state 디코딩·stale 시각·종료 3시간 뒤 해제 시각)와 `FestivalLiveActivityDedupTests`, App 테스트의 `LiveActivityIntegrationTests`(시작·종료·완료 종료)와 `LiveActivityTokenSyncTests`(토큰 등록·교체·해제·재시도)가 시뮬레이터에서 실행됩니다.
- 실기기 미확인: 축제 라이브 보드에서 켜기 → 갱신 → 끄기를 거친 iPhone Duo 잠금 화면 표시, 접힘·펼침 표시, 종료 3시간 뒤 자동 해제는 실기기로 확인하지 않았습니다. 실기기 원격 시작·갱신은 #58의 별도 완료 조건입니다.
