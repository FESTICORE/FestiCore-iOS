# 테스트와 CI

## 로컬 테스트

`./make test`는 `FestiCore-Stage` 스킴의 `FestiCore` 테스트 플랜을 실행합니다. `TuistTool.swift`는 `--no-selective-testing`을 사용하므로 전체 플랜을 대상으로 합니다. 새 테스트 타깃은 `Projects/App/Tests/FestiCore.xctestplan`에도 등록해야 합니다. `Scripts/select-ios-simulator.py`는 최신 사용 가능 iOS 런타임의 개인 작업용 iPhone Duo를 선택하며, 해당 런타임에 Duo가 없으면 실패합니다. 로컬 테스트는 이미 부팅된 Duo를 우선하고 CI 전용 기기는 사용하지 않습니다.

```bash
./make test
```

## GitHub Actions

| 워크플로 | 동작 |
| --- | --- |
| [PR Test Coverage](../.github/workflows/ios-pr.yml) | Stage 테스트를 두 shard로 분산하고 커버리지·번들 결과를 PR에 보고 |
| [develop tests](../.github/workflows/ios-develop-sharded-tests.yml) | develop의 분산 테스트 |
| [cache warm](../.github/workflows/ios-cache-warm.yml) | Tuist 캐시 준비 |
| [preview](../.github/workflows/ios-preview.yml) | 시뮬레이터 앱 빌드와 Tuist Preview |

PR 워크플로는 self-hosted macOS 러너에서 테스트 빌드 후 Tuist Test Sharding을 실행합니다. `--inspect-mode remote`로 결과를 [Tuist Tests](https://tuist.dev/FestiCore/festicore/tests/test-runs)에 전송하고, Swift Testing 결과와 코드 커버리지를 PR 리포트로 묶습니다. 앱 빌드가 성공하면 번들 분석도 실행합니다. Tuist 캐시가 준비되지 않으면 워크플로가 컴파일 캐시 없이 진행하도록 설정되어 있습니다.

CI는 최신 iOS 런타임에서 이름이 `FestiCore CI iPhone Duo`인 전용 기기 한 대만 사용합니다. 러너에서 기존 CI용 Duo를 이 이름으로 지정하고, 다른 Duo는 개인 작업용으로 둡니다. 전용 기기가 종료돼 있으면 CI가 부팅한 뒤 작업 종료 시 종료합니다. 이미 부팅돼 있으면 그대로 사용하며 CI가 종료하지 않습니다. 전용 기기가 없거나 상태가 전환 중이면 작업이 명확히 실패합니다.

CI의 통과 여부는 해당 커밋의 GitHub Actions 결과에서 확인합니다.
