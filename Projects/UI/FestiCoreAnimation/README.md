# FestiCoreAnimation

GIF는 기존 `FestiCoreAnimationView`로 표시합니다. Lottie는 호출자가 소유한 JSON 번들 에셋이나 HTTPS URL을 받습니다.

```swift
FestiCoreLottieView(.asset(name: "loading", bundle: .main))
  .duration(2)

FestiCoreLottieView(.remote(url: animationURL, format: .dotLottie))
```

원격 형식은 `.json` 또는 `.dotLottie`로 명시합니다. 로딩 중에는 진행 표시, 실패 시에는 경고 아이콘을 표시합니다. `.duration(_:)`은 한 번 재생할 시간을 초 단위로 지정하며, 유효하지 않은 값은 무시합니다.
