# 프로젝트와 구조

현재 FestiCore 코드와 설정을 기준으로 작업한다. 문서의 예시보다 실제 매니페스트와 소스가 우선한다.

## 앱

- 앱 이름: `FestiCore`; 번들 ID: `io.festiCore.co`; Apple Team ID: `N94CS4N6VR`.
- iOS 18.0 이상, iPhone 대상. Xcode 프로젝트는 Tuist로 생성한다.
- Stage/Prod 구성은 `Config/`와 Tuist 매니페스트를 확인한다.

## 모듈 구조

- `Projects/App`가 진입점이다. `FeatureAssembly`가 Feature와 Service 조립 모듈을 앱에 연결한다. `Projects/Feature`에는 화면, `Projects/Domain`에는 기능별 계약과 구현, `Projects/Service`에는 API와 세션 등 서비스, `Projects/Core`와 `Projects/UI`에는 공통 모듈을 둔다.
- `Plugins/ProjectTemplatePlugin`은 타깃과 스킴, `DependencyPlugin`은 내부 모듈, `DependencyPackagePlugin`은 외부 패키지 의존성을 정의한다.
- 새로운 모듈은 `Projects/<계층>/<이름>/Project.swift`로 등록한다.
- 앱이 개별 Feature 구현을 직접 import하지 않도록 `FeatureAssembly`에서 공개한다.
- DesignSystem의 원천 토큰과 생성 자동화는 별도 `FestiCore-DesignSystem` 저장소에서 관리한다. iOS 모듈에 토큰을 임의로 복제하거나 직접 수정하지 않는다.

의존 방향은 `.claude/scripts/check-boundaries`가 import 문으로 검사한다(규칙 표는 [하네스](harness.md)의 모듈 경계).

## 기준 저장소

- 모든 구조(모듈·폴더·파일 이름·코디네이터·테스트 배치)와 API·DI·UseCase·Repository의 배치와 주입은 Attendance_iOS(`DDD-Community/Attendance_iOS`, 로컬 `~/Desktop/SideProject/Attendance/Attendance_iOS`, 읽기 전용)를 따른다. 파일을 만들기 전에 Attendance `Projects/Domain/AttendanceDomain`, `Projects/Service/{API,APIEndpoint}`의 같은 역할 파일을 열어 대조한다.
- 분석(Sentry·Mixpanel)과 딥링크는 Picke-iOS(`SWYP-Find/Picke-iOS`) 구조를 따른다. [분석](analytics.md), [푸시·딥링크](push-deeplink.md).
