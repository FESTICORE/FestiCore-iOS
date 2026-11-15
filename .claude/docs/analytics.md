# 분석 (Sentry · Mixpanel)

Sentry·Mixpanel 코드(초기화·이벤트·화면 추적·성능 추적·오류 보고)는 `Projects/Service/FestiCoreAnalytics`에 두고, Picke-iOS(`SWYP-Find/Picke-iOS`) `Projects/Service/PickeAnalytics/Sources`의 아래 파일과 같은 구조·호출 방식으로 쓴다.

| Picke | 역할 |
| --- | --- |
| `Configuration/SentryConfiguration` · `MixpanelConfiguration` | 초기화 설정 |
| `UseCase/AnalyticsUseCase+Live` | `AnalyticsUseCase` 라이브 등록 |
| `Trace/PickeTracedView` | 화면 · 성능 추적 |

- 다른 모듈은 `FestiCoreAnalytics`의 `AnalyticsUseCase`를 주입받는다([의존성 주입](dependency-injection.md)).
- Sentry · Mixpanel을 다른 모듈에서 import하지 않는다. `.claude/scripts/check-boundaries`가 검사한다.
