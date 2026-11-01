//
//  WebRepresentableView.swift
//  Web
//
//  Created by FestiCore on 11/2/26.
//

import SwiftUI
import WebKit

/// WKWebView 래퍼. `loadID`가 바뀔 때만 다시 로드하고, 결과는 그 로드의 `loadID`와 함께 알린다.
struct WebRepresentableView: UIViewRepresentable {
  let url: URL
  let loadID: Int
  let onFinished: (Int) -> Void
  let onFailed: (Int) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(allowedHost: url.host)
  }

  func makeUIView(context: Context) -> WKWebView {
    let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    webView.navigationDelegate = context.coordinator
    webView.uiDelegate = context.coordinator
    webView.isOpaque = false
    webView.backgroundColor = .clear
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    let coordinator = context.coordinator
    coordinator.onFinished = onFinished
    coordinator.onFailed = onFailed
    guard loadID > 0, coordinator.currentLoadID != loadID else { return }
    coordinator.currentLoadID = loadID
    webView.stopLoading()
    webView.load(URLRequest(url: url))
  }
}

extension WebRepresentableView {
  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    let allowedHost: String?
    var currentLoadID = 0
    var onFinished: (Int) -> Void = { _ in }
    var onFailed: (Int) -> Void = { _ in }

    init(allowedHost: String?) {
      self.allowedHost = allowedHost
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
      switch WebNavigationPolicy.decide(
        request: navigationAction.request.url,
        isNewWindow: navigationAction.targetFrame == nil,
        allowedHost: allowedHost
      ) {
      case .allow:
        return .allow
      case .cancel:
        return .cancel
      case let .loadInPlace(url):
        // 새 창 요청은 취소하고, 판단이 끝난 뒤 지금 웹뷰로 연다.
        Task { @MainActor in webView.load(URLRequest(url: url)) }
        return .cancel
      }
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
      let statusCode = (navigationResponse.response as? HTTPURLResponse)?.statusCode
      guard WebNavigationPolicy.acceptsResponse(statusCode: statusCode, isMainFrame: navigationResponse.isForMainFrame) else {
        onFailed(currentLoadID)
        return .cancel
      }
      return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      onFinished(currentLoadID)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      report(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      report(error)
    }

    /// 새 창은 만들지 않는다. 허용된 주소는 decidePolicyFor에서 지금 웹뷰로 연다.
    func webView(
      _ webView: WKWebView,
      createWebViewWith configuration: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction,
      windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
      nil
    }

    private func report(_ error: Error) {
      // 정책으로 취소한 이동과 새 로드로 끊긴 이전 로드는 실패로 보지 않는다.
      if (error as NSError).code == NSURLErrorCancelled { return }
      onFailed(currentLoadID)
    }
  }
}
