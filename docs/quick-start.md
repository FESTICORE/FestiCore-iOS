# 빠른 시작

## 요구 사항

- Xcode 27.1
- [Mise](https://mise.jdx.dev/)
- iOS 18.0 이상 iPhone 시뮬레이터

## 워크스페이스 생성

새 작업 디렉터리에서 저장소를 복제한 뒤 실행합니다.

```bash
git clone https://github.com/FESTICORE/FestiCore-iOS.git
cd FestiCore-iOS
./make setup --no-open
open FestiCore.xcworkspace
```

`setup`은 Mise 도구 설치, Tuist 의존성 설치, 로컬 캐시 준비, 워크스페이스 생성을 순서대로 실행합니다. Xcode에서 `FestiCore-Stage` 스킴과 iPhone 시뮬레이터를 선택합니다. 이미 도구와 의존성이 준비된 경우 `./make generate --no-open`으로 워크스페이스를 다시 생성할 수 있습니다.

첫 빌드와 테스트는 [개발 환경](development.md)과 [테스트와 CI](testing-ci.md)를 참고합니다.
