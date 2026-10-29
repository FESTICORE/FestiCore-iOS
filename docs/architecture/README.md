# 아키텍처 그림

README는 SVG를 표시합니다. 같은 이름의 `.excalidraw` 파일은 [Excalidraw](https://excalidraw.com/)에서 편집할 수 있고, `.mmd` 파일은 그래프를 다시 만들 때 쓰는 Mermaid 정의입니다.

| 그림 | 범위 |
| --- | --- |
| `module-graph` | 현재 Tuist 모듈과 주요 의존성. 점선은 앱에 포함되는 확장 타깃입니다. |
| `tca-flow` | 현재 앱의 Splash → Home 상태 전환과 Home의 의존성 경계. |

모듈을 추가하거나 의존성을 바꾸면 해당 `Project.swift`와 `Modules.swift`를 확인한 뒤 `.mmd`를 수정합니다. Excalidraw의 **Mermaid를 Excalidraw로** 기능으로 새 그림을 만들고, 편집 가능한 `.excalidraw`와 README에 표시할 `.svg`를 함께 갱신합니다. 화면 경로를 바꾸면 `AppCoordinator`와 `HomeCoordinator`를 기준으로 `tca-flow`도 갱신합니다.

그림은 현재 구현을 설명합니다. Login 모듈은 존재하지만 `AppCoordinator`에 라우트가 없으며, Live Activity 원격 푸시 시작 경로도 그림에서 완성된 흐름으로 표시하지 않습니다.

## Tuist 의존성 그래프

`./make graph`는 현재 `Project.swift`에서 Tests·Interface를 포함한 `module-graph-all.png`를 생성합니다. `./make graph:prod`는 테스트 타깃을 뺀 `module-graph-prod.png`를 생성합니다. 두 명령 모두 외부 패키지와 Demo 타깃을 제외하고 `docs/architecture/`에 저장합니다. Graphviz의 `dot`이 필요합니다.

모듈을 추가하거나 의존성을 바꾼 뒤 두 명령을 다시 실행하고 생성된 PNG를 함께 커밋합니다. 위의 Excalidraw·Mermaid 그림은 주요 경계를 설명하는 요약 그림이므로, 구조가 바뀌면 함께 갱신합니다.
