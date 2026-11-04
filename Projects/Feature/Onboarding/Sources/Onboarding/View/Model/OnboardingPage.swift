import FestiCoreDesignKit

struct OnboardingPage {
  let imageAsset: ImageAsset
  let title: String
  let description: String

  static let all = [
    Self(
      imageAsset: ImageAsset(rawValue: "Visual-onboarding01"),
      title: "보고 싶은 무대만\n골라 담아요",
      description: "타임테이블에서 내 일정을 만들며\n겹치는 무대도, 시작 10분 전도 알려 드려요."
    ),
    Self(
      imageAsset: ImageAsset(rawValue: "Visual-onboarding02"),
      title: "현장에서 안 터져도\n괜찮아요",
      description: "페스티벌 팩을 미리 받아 두면 타임테이블,\n존 지도, 가는 길이 오프라인에서도 열려요."
    ),
    Self(
      imageAsset: ImageAsset(rawValue: "Visual-onboarding03"),
      title: "지금 어느 무대가\n뜨거운지 한눈에",
      description: "무대별 지금·다음 공연과 실제 진행 상황을\n라이브 보드 한 화면에서 확인해요."
    ),
    Self(
      imageAsset: ImageAsset(rawValue: "Visual-onboarding04"),
      title: "따라갈 깃발을\n찾아보세요",
      description: "슬램·떼창... 나와 맞는 깃발을 팔로우하면\n지금 어느 존에서 뭘 하는지 알려 드려요."
    ),
  ]
}
