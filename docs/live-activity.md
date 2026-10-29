# Live Activity

`Projects/UI/FestiCoreLiveActivity`의 `FestiCoreFestivalLiveActivity`는 축제 활동의 시작, 상태 갱신, 종료와 원격 갱신용 push token 관찰 API를 제공합니다. 별도 `Projects/Widget/FestiCoreWidget` 프로젝트의 `FestiCoreLiveActivityExtension`은 잠금 화면과 Dynamic Island용 `ActivityConfiguration`을 선언합니다. 앱 Info.plist에는 `NSSupportsLiveActivities`가 설정되어 있고 App 타깃은 확장에 의존합니다.

`Projects/Service/FestiCoreDevice`는 기기 등록과 `PUT/DELETE /api/v1/devices/live-activity` 요청을 제공합니다. 앱 시작 시 일반 기기 등록을 시도하지만 APNs 토큰은 현재 `nil`로 보냅니다. 축제 화면에서 활동을 시작하는 호출과 ActivityKit push token을 서버에 보내는 연결은 아직 없습니다.

현재 확인 범위는 확장 빌드와 ActivityKit 요청·WidgetRenderer 콘텐츠 로드 로그까지입니다. iPhone Duo 화면 캡처에서 Live Activity의 실제 표시를 확정하지 못했으며 실기기 원격 갱신도 검증하지 않았습니다. 임시 smoke 호출은 소스에서 제거했습니다. 화면 연결과 기기 검증을 마친 뒤 이 문서의 상태를 갱신해야 합니다.
