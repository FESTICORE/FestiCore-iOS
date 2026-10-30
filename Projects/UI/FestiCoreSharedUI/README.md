# FestiCoreSharedUI

원격 이미지는 Kingfisher 캐시를 사용합니다. URL이 없거나 로드에 실패하면 DesignKit의 `fillNormal` 색상을 보여줍니다.

```swift
FCRemoteImage(url: imageURL)
  .content(.fill)
  .frame(width: 120, height: 120)
```

`.content(.fit)`으로 이미지 전체가 보이게 할 수 있습니다. 이미지 크기는 호출부의 `.frame(width:height:)` 또는 `.aspectRatio(_:)`로 지정합니다. 로딩 중에는 DesignKit `FCSkeletonView`, URL이 없거나 실패하면 `fillNormal`을 표시하고, 성공한 이미지의 투명 영역에는 부모 배경이 보입니다. 원격 SVG는 SVGKit 기반 `SVGProcessor`로 그리고, 캐시에는 원본 SVG 데이터를 둡니다.

다운로드 실패 후 같은 URL을 자동으로 재시도하지 않습니다. 다시 시도하려면 URL을 바꾸거나 호출부에서 `.id(retryToken)`을 바꿔 뷰 상태를 새로 만듭니다.

## 확인 다이얼로그

Feature 상태에 `@Presents var alert: FCAlertState<FCAlertAction>?`를 두고 리듀서에서 `.ifLet(\.$alert, action: \.alert) { FCConfirmAlert() }`로 연결합니다. 화면에서는 `.fcAlert($store.scope(\.alert, action: \.alert))`로 띄웁니다. 클로저로 처리하는 단순한 경우는 `FCDialogItem`과 `.fcDialog(item:)`을 사용합니다.

## 시트와 팝업

Attendance와 같이 범용 표현은 DesignKit에, FestiCore 화면 내용은 이 모듈에 둡니다.

- DesignKit: 바텀시트 `presentFCSheet(item:)`(`Component/Modal`), 토스트 `FCToast`·`fcToast(item:)`(`Component/Toast`), 확인 팝업 `FCDialog`·완료 팝업 `FCCheckOverlay`(`Component/PopUp`)
- SharedUI: 로그인·셋 상세·신고·기수 선택 시트 내용(`Sources/Sheet`), 화면별 토스트 문구 `FCToast.Item.booked()` 등(`Sources/Toast`), TCA 확인 다이얼로그(`Sources/Alert`)

시트 내용은 DesignKit `presentFCSheet(item:)`로 띄우고, 색상·서체·버튼은 DesignKit 토큰과 컴포넌트를 사용합니다.
