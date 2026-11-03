import ComposableArchitecture
import FestiCoreDesignKit
import SwiftUI

@ViewAction(for: OnboardingFeature.self)
public struct OnboardingView: View {
  public let store: StoreOf<OnboardingFeature>

  public init(store: StoreOf<OnboardingFeature>) {
    self.store = store
  }

  public var body: some View {
    GeometryReader { geometry in
      TabView(selection: pageSelection) {
        ForEach(OnboardingPage.all.indices, id: \.self) { index in
          pageView(at: index, size: geometry.size)
            .tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .background(Color.backgroundNormal)
    }
    .background(Color.backgroundNormal.ignoresSafeArea())
  }
}

private extension OnboardingView {
  var pageSelection: Binding<Int> {
    Binding(
      get: { store.page },
      set: { store.send(.view(.pageChanged($0))) }
    )
  }

  func pageView(at index: Int, size: CGSize) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer()
        Button("건너뛰기") { send(.skipTapped) }
          .pretendardFont(family: .Medium, size: 15)
          .foregroundStyle(Color.labelNeutral)
          .accessibilityIdentifier("onboarding.skip")
      }
      .padding(.top, 16)

      Spacer(minLength: 16)

      Button {
        send(.nextTapped)
      } label: {
        Image(
          OnboardingPage.all[index].imageName,
          bundle: Bundle(for: OnboardingBundleMarker.self)
        )
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity)
          .frame(height: min(431, max(200, size.height - 320)))
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(index == OnboardingPage.all.count - 1 ? "시작하기" : "다음 화면")
      .accessibilityIdentifier("onboarding.next")

      Spacer(minLength: 16)

      VStack(alignment: .leading, spacing: 12) {
        Text(OnboardingPage.all[index].title)
          .pretendardFont(family: .Bold, size: 26)
          .foregroundStyle(Color.labelNormal)
          .fixedSize(horizontal: false, vertical: true)

        Text(OnboardingPage.all[index].description)
          .festiCoreFont(.baseCalloutRegular)
          .foregroundStyle(Color.labelNeutral)
          .lineSpacing(5)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack(spacing: 8) {
        ForEach(OnboardingPage.all.indices, id: \.self) { dot in
          Circle()
            .fill(dot == index ? Color.primaryNormal : Color.fillStrong)
            .frame(width: 8, height: 8)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(index + 1) / \(OnboardingPage.all.count) 페이지")
      .padding(.top, 34)
      .padding(.bottom, 48)
    }
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.backgroundNormal)
  }
}

final class OnboardingBundleMarker {}
