# 디자인 시스템

`Projects/UI/FestiCoreDesignKit`은 [FestiCore-DesignSystem](https://github.com/FESTICORE/FestiCore-DesignSystem)의 토큰을 바탕으로 생성한 Swift 색상·타이포그래피·간격 API와 수작업 UI 컴포넌트를 제공합니다. 토큰 JSON 스냅샷과 출처 SHA를 보관합니다.

화면에는 semantic 색상을 사용하고 atomic 색상은 토큰 참조에 둡니다. 색상은 에셋 팔레트 대신 Swift 코드로 정의합니다. base·point 타이포그래피 모두 DesignKit에 번들한 Pretendard를 사용하며, `festiCoreFont(.baseBodyRegular)`처럼 적용합니다. 토큰의 크기·자간·행간을 유지하기 위해 고정 크기 폰트를 사용합니다. 이미지 자산은 `Resources/ImageAssets.xcassets`에 추가하고 `Image(assetName:)` 또는 `UIImage(assetName:)`으로 읽습니다. 등록되지 않은 이미지는 SwiftUI에서 `questionmark`로 대체됩니다.

`FestiCoreDesignKitDemo` 스킴에서 색상, 타이포그래피, 버튼 상태를 확인할 수 있습니다. Demo와 테스트 스킴은 분리되어 있습니다.

## 토큰 동기화

[디자인 토큰 워크플로](../.github/workflows/design-token-sync.yml)는 6시간마다 원본 저장소의 `main`을 확인하며 수동 실행도 지원합니다. 원본 커밋을 고정해 생성물과 JSON을 가져온 뒤 DesignKit 및 Stage 테스트와 커버리지를 검증합니다. 변경이 있으면 `develop` 대상 PR을 만들도록 구성되어 있습니다. 실제 PR 생성 여부와 CI 결과는 해당 실행 기록에서 확인해야 합니다.

토큰 값을 변경할 때는 원본 디자인 저장소를 먼저 갱신합니다. 코드와 토큰 구조의 배경은 [Core·UI 공통 모듈 설계](core-ui-modules-design.md)를 참고합니다.
