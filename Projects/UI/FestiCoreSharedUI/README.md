# FestiCoreSharedUI

원격 이미지는 Kingfisher 캐시를 사용합니다. URL이 없거나 로드에 실패하면 DesignKit의 `fillNormal` 색상을 보여줍니다.

```swift
FestiCoreRemoteImage(url: imageURL)
  .content(.fill)
  .frame(width: 120, height: 120)
```

`.content(.fit)`으로 이미지 전체가 보이게 할 수 있습니다. 원격 SVG 처리기는 포함하지 않습니다.
