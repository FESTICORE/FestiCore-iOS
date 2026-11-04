# 아키텍처 그림

README의 Mermaid 그림은 주요 모듈 의존성을 요약합니다. `.mmd` 파일에는 화면 경로와 데이터 흐름도 있습니다. 같은 이름의 `.excalidraw` 파일은 [Excalidraw](https://excalidraw.com/)에서 편집할 수 있습니다.

| 그림 | 범위 |
| --- | --- |
| [module-graph.mmd](module-graph.mmd) | 현재 Tuist 모듈과 주요 의존성. 점선은 앱에 포함되는 확장 타깃입니다. |
| [tca-flow.mmd](tca-flow.mmd) | Splash → 첫 설치 온보딩 또는 탭 → 축제·알림함·마이 하위 화면 전환. |
| [feature-data-flow.mmd](feature-data-flow.mmd) | 화면 → UseCase → Repository → S00 목록·팩 서비스의 요청·캐시 경계. |

모듈을 추가하거나 의존성을 바꾸면 해당 `Project.swift`와 `Modules.swift`를 확인한 뒤 README의 Mermaid 흐름과 `module-graph.mmd`를 수정합니다. 화면 경로는 `tca-flow.mmd`, 화면의 데이터 경계는 `feature-data-flow.mmd`에 반영합니다. SVG 요약이 바뀌면 Excalidraw 원본과 SVG도 갱신합니다.

그림은 현재 구현을 설명합니다. Live Activity 원격 푸시 시작 경로는 완성된 흐름으로 표시하지 않습니다.

## Tuist 의존성 그래프

`./make graph`는 현재 `Project.swift`에서 Tests·Interface를 포함한 `module-graph-all.png`를 생성합니다. `./make graph:prod`는 테스트 타깃을 뺀 `module-graph-prod.png`를 생성합니다. 두 명령 모두 외부 패키지와 Demo 타깃을 제외하고 `docs/architecture/`에 저장합니다. Graphviz의 `dot`이 필요합니다.

현재 요약 도식의 Auth 모듈 이름은 `.mmd`와 `.svg`에 반영되어 있습니다. 두 PNG는 Auth 이름 변경 전 생성본이며, Tuist 외부 의존성 설치 후 다시 생성해야 합니다.

모듈을 추가하거나 의존성을 바꾼 뒤 두 명령을 다시 실행하고 생성된 PNG를 함께 커밋합니다. 위의 Excalidraw·Mermaid 그림은 주요 경계를 설명하는 요약 그림이므로, 구조가 바뀌면 함께 갱신합니다.
