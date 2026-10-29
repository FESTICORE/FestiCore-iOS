# Live Activity

`Projects/UI/FestiCoreLiveActivity`의 `FestiCoreFestivalLiveActivity`는 축제 활동의 시작, 상태 갱신, 종료와 원격 갱신용 push token 관찰 API를 제공합니다. 별도 `Projects/Widget/FestiCoreWidget` 프로젝트의 `FestiCoreLiveActivityExtension`은 잠금 화면과 Dynamic Island용 `ActivityConfiguration`을 선언합니다. 앱 Info.plist에는 `NSSupportsLiveActivities`가 설정되어 있고 App 타깃은 확장에 의존합니다.

`Home`의 축제 상세에서 사용자가 Live Activity를 켜거나 끌 수 있습니다. 시작은 축제 첫날 2시간 전부터 마지막 날 종료 전까지 가능하며, ActivityKit이 약 8시간 후 활동을 종료하면 다시 켤 수 있습니다. 앱이 활성 상태인 동안 축제 시작·종료 경계와 카탈로그 변경에 맞춰 모든 진행 중인 축제 활동을 갱신합니다. 앱을 다시 열면 ActivityKit 목록에서 활동을 복원합니다. 앱이 실행되지 않을 때 정확한 시각에 갱신하거나 원격으로 시작하는 기능은 #58에서 추적합니다.

`YYYY-MM-DD` 일정은 서울 시간 그날 00:00부터 다음 날 00:00 전까지로 해석합니다. 오프셋을 포함한 ISO 8601 타임스탬프는 적힌 정확한 시각으로 해석하며 `lastDate`도 종료 시각입니다. 앱이 백그라운드에 있는 동안 그 시각을 지나면 잠금 화면 콘텐츠는 stale로 표시됩니다.

`Projects/Service/FestiCoreDevice`는 기기 등록과 `PUT/DELETE /api/v1/devices/live-activity` 요청을 제공합니다. 앱 시작 시 일반 기기 등록을 시도합니다. ActivityKit push token을 서버에 보내는 제품 연결은 아직 없습니다.

현재 확인 범위와 남은 기기 검증은 #105에 기록합니다. 이전에 사용자가 iPhone Duo 잠금 화면 표시를 확인했다고 알려주었지만, 축제 상세에서 켜기 → 갱신 → 끄기와 접힘·펼침 표시를 제품 흐름으로 재검증해야 합니다. 실기기 원격 갱신은 #58의 별도 완료 조건입니다.
