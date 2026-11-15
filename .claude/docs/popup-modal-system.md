# 팝업과 모달

화면마다 `modalOverlay`·`dialogOverlay` 같은 별도 오버레이를 만들지 않는다. 아래 두 가지만 쓴다. 표시 상태는 화면 리듀서가 `@Presents`로 소유한다.

## 확인 팝업: `FestiCoreSharedUI/Sources/Alert`

| 파일 | 역할 |
| --- | --- |
| `FCAlertState.swift` | `FCAlertState<Action>`, `FCAlertStyle`, `FCAlertAction`, 정적 팩토리(`.logout()` 등) |
| `FCAlertModifiers.swift` | `.fcAlert(_:)` 표시 모디파이어 |
| `FCConfirmationPopupView.swift` | 딤과 DesignKit `FCDialog`를 그리는 팝업 View |

```swift
// 리듀서
@Presents public var customAlert: FCAlertState<FCAlertAction>?
case scope(ScopeAction)  // ScopeAction: case customAlert(PresentationAction<FCAlertAction>)
.ifLet(\.$customAlert, action: \.scope.customAlert) { EmptyReducer() }

// View
.fcAlert($store.scope(state: \.customAlert, action: \.scope.customAlert))
```

- 문구는 `FCAlertState`의 정적 팩토리로 모은다. 확인·취소 처리는 리듀서의 `handleScopeAction`에서 한다.

## 바텀시트 모달: `FestiCoreSharedUI/Sources/Modal`

```swift
// 리듀서
@Presents public var setDetail: SetDetailFeature.State?
.ifLet(\.$setDetail, action: \.scope.setDetail) { SetDetailFeature() }

// View
.fcModal($store.scope(state: \.setDetail, action: \.scope.setDetail)) { store in
  SetDetailView(store: store)
}
```

- 손잡이, 모서리, 딤, 끌어서 닫기는 DesignKit 바텀시트를 그대로 쓴다. 끌거나 딤을 눌러 닫으면 `.dismiss`가 간다.
- 탭바까지 덮어야 하는 모달은 탭을 그리는 상위 View에서 자식 store를 scope해 같은 모디파이어를 붙인다.

접근성 포커스, 닫기 동작, 중복 표시를 화면 테스트에서 확인한다.
