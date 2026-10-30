import UIKit

// SwiftUI의 숨긴 뒤로 버튼이 비활성화한 기본 가장자리 뒤로 가기를 복구합니다.
// Attendance_iOS의 DDDCoreUI UINavigationController+gesture.swift 패턴을 따릅니다.
extension UINavigationController: UIGestureRecognizerDelegate {
  override open func viewDidLoad() {
    super.viewDidLoad()
    restoreSwipeBackGesture()
  }

  public func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
    canSwipeBack
  }

  var canSwipeBack: Bool {
    viewControllers.count > 1
  }

  func restoreSwipeBackGesture() {
    guard let interactivePopGestureRecognizer else { return }
    interactivePopGestureRecognizer.delegate = self
    interactivePopGestureRecognizer.isEnabled = canSwipeBack
  }
}
