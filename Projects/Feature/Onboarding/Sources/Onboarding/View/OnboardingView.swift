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
    return GeometryReader { geometry in
      // 건너뛰기와 페이지 점은 한 화면에 고정하고 그림·문구만 넘긴다.
      VStack(
        alignment: .leading,
        spacing: .zero
      ) {
        topActions

        TabView(selection: pageSelection) {
          ForEach(
            OnboardingPage.all.indices,
            id: \.self
          ) { index in
            pageContents(
              at: index,
              size: geometry.size
            )
            .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        pageIndicator
      }
      .background(Color.backgroundNormal)
    }
    .background(Color.backgroundNormal.ignoresSafeArea())
  }
}

private extension OnboardingView {
  var pageSelection: Binding<Int> {
    return Binding(
      get: { store.page },
      set: { store.send(.view(.pageChanged($0))) }
    )
  }

  /// Figma Onboarding Top Actions: 높이 52, 좌우 8, ghost·M 건너뛰기 버튼
  var topActions: some View {
    return HStack {
      Spacer()
      FCButton("건너뛰기") { send(.skipTapped) }
        .style(.ghost)
        .size(.medium)
        .accessibilityIdentifier("onboarding.skip")
    }
    .frame(height: 52)
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP8
    )
  }

  /// Figma Onboarding Contents의 그림·문구: 간격 32, 좌우 24·위 24
  func pageContents(
    at index: Int,
    size: CGSize
  ) -> some View {
    return VStack(
      alignment: .leading,
      spacing: Metric.contentSpacing
    ) {
      Button {
        // 그림을 눌러 넘길 때도 스와이프처럼 페이지가 밀려 나간다.
        send(
          .nextTapped,
          animation: .easeInOut(duration: Metric.pageAnimationDuration)
        )
      } label: {
        Image(
          OnboardingPage.all[index].imageAsset.rawValue,
          bundle: Bundle(for: OnboardingBundleMarker.self)
        )
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity)
          // Figma Onboarding 그림 431 = 화면 높이 - (상단 52 + 위 24 + 간격 32 + 문구 140 + 간격 32 + 점 8 + 아래 40)
          .frame(height: min(
            Metric.visualMaxHeight,
            max(
              Metric.visualMinHeight,
              size.height - Metric.nonVisualHeight
            )
          ))
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(index == OnboardingPage.all.count - 1 ? "시작하기" : "다음 화면")
      .accessibilityIdentifier("onboarding.next")

      // Figma Onboarding Text: 제목 Title 1/Bold(28/38)·설명 Body/Regular(17/26), 간격 12
      VStack(
        alignment: .leading,
        spacing: FestiCoreSpacing.paddingP12
      ) {
        Text(OnboardingPage.all[index].title)
          .festiCoreFont(.baseTitle1Bold)
          .festiCoreLineBox(.baseTitle1Bold)
          .foregroundStyle(Color.labelNormal)
          .fixedSize(horizontal: false, vertical: true)

        Text(OnboardingPage.all[index].description)
          .festiCoreFont(.baseBodyRegular)
          .festiCoreLineBox(.baseBodyRegular)
          .foregroundStyle(Color.labelNeutral)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP24
    )
    .padding(
      .top,
      FestiCoreSpacing.paddingP24
    )
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity,
      alignment: .top
    )
  }

  /// Figma Onboarding 페이지 점: 8×8, 간격 8, 문구와 32 · 아래 40. 넘기면 현재 점만 바뀐다.
  var pageIndicator: some View {
    return HStack(spacing: 8) {
      ForEach(
        OnboardingPage.all.indices,
        id: \.self
      ) { dot in
        Circle()
          .fill(dot == store.page ? Color.primaryNormal : Color.fillStrong)
          .frame(
            width: 8,
            height: 8
          )
      }
    }
    .animation(
      .easeInOut(duration: Metric.pageAnimationDuration),
      value: store.page
    )
    .padding(
      .horizontal,
      FestiCoreSpacing.paddingP24
    )
    .padding(
      .top,
      Metric.contentSpacing
    )
    .padding(
      .bottom,
      Metric.bottomPadding
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(store.page + 1) / \(OnboardingPage.all.count) 페이지")
    .accessibilityIdentifier("onboarding.pageIndicator")
  }
}

private extension OnboardingView {
  enum Metric {
    static let contentSpacing: CGFloat = 32
    static let bottomPadding: CGFloat = 40
    static let visualMaxHeight: CGFloat = 431
    static let visualMinHeight: CGFloat = 200
    static let nonVisualHeight: CGFloat = 328
    static let pageAnimationDuration: Double = 0.3
  }
}

final class OnboardingBundleMarker {}
