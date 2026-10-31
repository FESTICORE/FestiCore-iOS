# 개발 환경

## 현재 설정

- `Tuist.swift`는 Xcode 호환 버전, Swift 6.4와 플러그인을 설정한다.
- `Workspace.swift`는 `Projects/**`의 프로젝트를 모은다.
- `Config/Stage.xcconfig`와 `Config/Prod.xcconfig`는 환경별 빌드 값을 제공한다. API 호스트는 예시 값이므로 서버 연동 전에 실제 값을 확인한다.
- 앱 배포 대상은 iOS 18.0 이상 iPhone이다.

## 명령

저장소 루트의 `./make help`로 지원 명령과 인자를 확인한다. 처음 설정할 때 `./make setup`, 프로젝트 변경 뒤 `./make generate`, 검증 시 `./make build`와 `./make test`를 사용한다. 특정 시뮬레이터, 서명 및 원격 CI 결과는 각 실행 결과로 확인한다.

새 파일을 생성한 후에는 Tuist 프로젝트를 다시 생성해 Xcode에 반영한다. `.xcodeproj`와 `.xcworkspace`는 생성 산출물이다.

## Xcode 컴파일 캐시 전환

새 Mac에서 처음 설정하거나 공유 캐시 서비스가 없을 때, 또는 이전 프로젝트별 캐시 소켓의 연결 오류를 복구할 때는 이 Mac의 모든 Xcode·Tuist 빌드가 끝난 뒤 아래 명령을 실행한다. `./make generate`만 실행하면 공유 캐시 서비스가 설치되지 않아 생성된 프로젝트의 캐시 연결이 실패할 수 있다.

```sh
./make setup
test -S "$HOME/.local/state/tuist/cas-proxy.sock"
lsof -nP "$HOME/.local/state/tuist/cas-proxy.sock"
```

`./make setup`은 Mise 도구와 Tuist 의존성을 설치하고 `tuist setup cache`로 공유 서비스를 준비한 뒤 바이너리 캐시를 예열하고 프로젝트를 생성한다. 예열 단계도 빌드를 수행하므로 다른 빌드와 겹치지 않게 실행한다. 위 소켓 확인 명령은 기본 상태 디렉터리 기준이다. 생성된 프로젝트의 `COMPILATION_CACHE_REMOTE_SERVICE_PATH`가 가리키는 소켓에 실제 리스너가 있는지도 확인한다.
