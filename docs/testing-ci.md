# 테스트와 CI

## 로컬 테스트

`./make test`는 `FestiCore-Stage` 스킴의 `FestiCore` 테스트 플랜을 실행합니다. `TuistTool.swift`는 `--no-selective-testing`을 사용하므로 전체 플랜을 대상으로 합니다. 새 테스트 타깃은 `Projects/App/Tests/FestiCore.xctestplan`에도 등록해야 합니다. 실행할 iPhone 시뮬레이터는 `Scripts/select-ios-simulator.py`가 선택합니다.

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

CI의 통과 여부는 해당 커밋의 GitHub Actions 결과에서 확인합니다.
