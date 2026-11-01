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
    /// 이미 실패를 알린 시도. 그 뒤 오는 취소 콜백이 결과를 바꾸지 않게 한다.
    private var failedLoadIDs: Set<Int> = []
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

    /// 어느 시도에서 시작됐는지 모르는 navigation 콜백은 무시한다.
    private func loadID(for navigation: WKNavigation?) -> Int? {
      navigation.flatMap { loadIDs[ObjectIdentifier($0)] }
    }

    private func fail(_ loadID: Int) {
      guard !failedLoadIDs.contains(loadID) else { return }
      failedLoadIDs.insert(loadID)
      if loadID == currentLoadID { isAwaitingFirstPage = false }
      onFailed(loadID)
    }

    /// 링크·리다이렉트·지금 웹뷰로 연 새 창 이동도 시작 시점의 시도에 묶는다.
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      guard let navigation, loadIDs[ObjectIdentifier(navigation)] == nil else { return }
      loadIDs[ObjectIdentifier(navigation)] = currentLoadID
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
          fail(currentLoadID)
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
      // 거절한 main frame 응답은 지금 시도의 실패로 바로 알리고, 뒤이은 취소 콜백은 fail에서 걸러진다.
      guard WebNavigationPolicy.acceptsResponse(statusCode: statusCode, isMainFrame: navigationResponse.isForMainFrame) else {
        fail(currentLoadID)
        return .cancel
      }
      return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      guard let id = loadID(for: navigation), !failedLoadIDs.contains(id) else { return }
      if id == currentLoadID { isAwaitingFirstPage = false }
      onFinished(id)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      guard let id = loadID(for: navigation) else { return }
      report(error, loadID: id)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      guard let id = loadID(for: navigation) else { return }
      report(error, loadID: id)
    }

    /// 웹 콘텐츠 프로세스가 끝나면 빈 화면 대신 실패와 다시 시도를 보인다.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
      fail(currentLoadID)
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
      fail(loadID)
    }
  }
}
