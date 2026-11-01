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
    coordinator.start(loadID: loadID, url: url, in: webView)
  }
}

extension WebRepresentableView {
  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    let allowedHost: String?
    private(set) var currentLoadID = 0
    /// 이번 시도에서 아직 첫 페이지를 받지 못했다. 이때 막힌 main frame 이동은 실패로 본다.
    private var isAwaitingFirstPage = false
    /// 각 WKNavigation이 어느 시도에서 시작됐는지. 멈춘 이전 시도의 늦은 콜백을 걸러 낸다.
    private var loadIDs: [ObjectIdentifier: Int] = [:]
    var onFinished: (Int) -> Void = { _ in }
    var onFailed: (Int) -> Void = { _ in }

    init(allowedHost: String?) {
      self.allowedHost = allowedHost
    }

    func start(loadID: Int, url: URL, in webView: WKWebView) {
      currentLoadID = loadID
      isAwaitingFirstPage = true
      webView.stopLoading()
      if let navigation = webView.load(URLRequest(url: url)) {
        loadIDs[ObjectIdentifier(navigation)] = loadID
      }
    }

    /// 시도 ID를 모르는 navigation(페이지 안 링크·리다이렉트)은 지금 시도로 본다.
    private func loadID(for navigation: WKNavigation?) -> Int {
      navigation.flatMap { loadIDs[ObjectIdentifier($0)] } ?? currentLoadID
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
        // 첫 페이지 전에 main frame이 막히면(다른 호스트·http 리다이렉트) 로딩에 머물지 않게 실패로 넘긴다.
        if isAwaitingFirstPage, navigationAction.targetFrame?.isMainFrame == true {
          isAwaitingFirstPage = false
          onFailed(currentLoadID)
        }
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
      // 거절한 응답은 취소만 하고, 뒤이은 didFailProvisional이 해당 navigation의 시도 ID로 실패를 알린다.
      guard WebNavigationPolicy.acceptsResponse(statusCode: statusCode, isMainFrame: navigationResponse.isForMainFrame) else {
        return .cancel
      }
      return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      let id = loadID(for: navigation)
      if id == currentLoadID { isAwaitingFirstPage = false }
      onFinished(id)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      report(error, loadID: loadID(for: navigation))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      report(error, loadID: loadID(for: navigation))
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

    private func report(_ error: Error, loadID: Int) {
      // 새 로드로 끊긴 이전 로드(NSURLErrorCancelled)는 실패로 보지 않는다.
      // HTTP 오류로 응답을 거절하면 WebKit 정책 변경 오류(102)가 오며 이는 실패로 알린다.
      if (error as NSError).domain == NSURLErrorDomain, (error as NSError).code == NSURLErrorCancelled { return }
      onFailed(loadID)
    }
  }
}
