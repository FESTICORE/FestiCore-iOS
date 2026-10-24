# 아키텍처

FestiCore는 SwiftUI 기반 Tuist 멀티모듈 프로젝트입니다. `Workspace.swift`가 `Projects/**`를 포함합니다. Home은 The Composable Architecture(TCA), 앱의 화면 연결은 TCAFlow를 사용합니다.

| 경로 | 현재 역할 |
| --- | --- |
| `Projects/App` | 앱 진입점, AppCoordinator, Stage·Prod 설정 |
| `Projects/Feature/Home` | Home 화면과 Reducer |
| `Projects/Feature/FeatureAssembly` | Feature와 Service 연결 |
| `Projects/Service/ServiceAssembly` | 앱에 제공할 서비스 의존성 조립 |
| `Projects/Service/FestiCoreAuth` | 자격 증명 저장과 토큰 갱신 |
| `Projects/Service/FestiCoreDevice` | 기기 및 Live Activity 토큰 서버 등록 |
| `Projects/Core/CoreAssembly` | Network·Storage 구현 생성 경계 |
| `Projects/Core/FestiCoreNetwork` | HTTP 요청, 인증, 업로드 |
| `Projects/Core/FestiCoreStorage` | Keychain과 공유 값 저장 |
| `Projects/Core/FestiCoreLogger` | 공통 로그 API |
| `Projects/UI/FestiCoreDesignKit` | 디자인 토큰과 컴포넌트 |
| `Projects/UI/FestiCoreSharedUI` | 공통 UI |
| `Projects/UI/FestiCoreAnimation` | 애니메이션 표시 API |
| `Projects/UI/FestiCoreLiveActivity` | 축제 활동 상태 API와 Widget 확장 |

현재 Widget 확장 타깃 `FestiCoreLiveActivityExtension`은 `Projects/UI/FestiCoreLiveActivity/Project.swift`에 선언되어 앱에 포함됩니다. 모듈 경계가 바뀌면 이 문서도 함께 갱신합니다. Domain/Data는 구체적인 기능 계약이 생길 때 추가하는 구조입니다.

## 의존성 주입

앱은 `FestiCoreApp.init()`의 `prepareDependencies`에서 `ServiceDependencyAssembly.register(into:)`를 호출합니다. ServiceAssembly는 CoreAssembly의 Network·Storage 생성 함수를 사용합니다. 테스트는 Point-Free Dependencies의 의존성 값을 교체합니다.

네트워크 요청 계약은 `FestiCoreNetwork/Interface`, 구현은 `Sources`에 둡니다. 인증 요청은 `NetworkClientFactory.unified(store:refresher:baseURL:)`, 일반 요청은 `NetworkClientFactory.plain(baseURL:)`가 생성합니다. 로그인·로그아웃 후 자격 증명은 반환된 `credentials.update(_:)`로 갱신합니다.

모듈 생성 방법은 [개발 환경](development.md), 이전 설계 배경은 [초기 설정 설계](initial-setup-design.md)와 [Core·UI 공통 모듈 설계](core-ui-modules-design.md)를 참고합니다. 설계 문서의 계획은 현재 구현과 다를 수 있으므로 실제 `Project.swift`와 소스를 우선합니다.
