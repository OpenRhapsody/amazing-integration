//
//  AmazingWebViewController.swift
//  AmazingIntegration
//
//  Created by Leo Kim on 8/14/25.
//

import UIKit
@preconcurrency import WebKit
import AudioToolbox

class UserContentControlAgent: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        self.delegate?.userContentController(userContentController, didReceive: message)
    }
}

class UserContentControlAgentAsync: NSObject, WKScriptMessageHandlerWithReply {
    weak var delegate: WKScriptMessageHandlerWithReply?
    
    init(delegate: WKScriptMessageHandlerWithReply) {
        self.delegate = delegate
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
        if #available(iOS 14.0, *) {
            self.delegate?.userContentController(userContentController, didReceive: message, replyHandler: replyHandler)
        }
    }
}

class AmazingWebViewController: UIViewController {
    private var activityIndicatorView: UIActivityIndicatorView?
    private var pageLoadTimeoutTimer: Timer?
    let url: URL!
    
    private var failedToLoad: Bool = false
    private var webView: WKWebView!
    
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    
    deinit {
        pageLoadTimeoutTimer?.invalidate()
    }
    
    required init?(coder: NSCoder) {
        self.url = URL(string: "")
        super.init(coder: coder)
        modalPresentationStyle = .fullScreen
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        overrideUserInterfaceStyle = .light
        
        let contentController = WKUserContentController()
        if #available(iOS 14.0, *) {
            // 햅틱, getAppVersion 브릿지
            let contentWorld = WKContentWorld.page
            let script = WKUserScript(source: """
                                                    window.bridge = {
                                                        callHandler: async function(name, sig, payload) {
                                                            return await window.webkit.messageHandlers.bridge.postMessage({ 
                                                                sig,
                                                                payload
                                                            });
                                                        }
                                                    };
                """, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: contentWorld)
            contentController.addUserScript(script)
            contentController.addScriptMessageHandler(UserContentControlAgentAsync(delegate: self), contentWorld: contentWorld, name: "bridge")
        }
        
        // close 브릿지
        contentController.add(UserContentControlAgent(delegate: self), name: "adrop")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let webView = WKWebView(frame: view.bounds, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .clear
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        if let url = self.url {
            webView.load(URLRequest(url: url))
        }
        
        self.webView = webView
        
        let activityIndicatorView = UIActivityIndicatorView(style: .medium)
        activityIndicatorView.color = .gray
        activityIndicatorView.startAnimating()
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(activityIndicatorView)
        NSLayoutConstraint.activate([
            activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        pageLoadTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: { [weak self] _ in
            self?.alertToClose()
        })
        
        self.activityIndicatorView = activityIndicatorView
    }
    
    private func isAmazingURL(_ url: URL) -> Bool {
        // 예외 처리할 도메인 패턴 목록
        let patterns = [
            #"^([a-zA-Z0-9-]+\.)*a2zing\.io$"#,
            #"^([a-zA-Z0-9-]+\.)*adrop\.io$"#
        ]
        
        // 도메인 매칭
        if let host = url.host, isMatchingDomain(host, patterns: patterns) {
            return true
        } else {
            return false
        }
    }
    
    // 정규식을 활용한 도메인 매칭 함수
    func isMatchingDomain(_ host: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if let _ = host.range(of: pattern, options: .regularExpression) {
                return true
            }
        }
        return false
    }
    
    private func close() {
        dismiss(animated: true)
    }
    
    fileprivate func alertToClose() {
        failedToLoad = true
        stopTimerAndHideActivityIndicator()
        
        let alert = UIAlertController(
            title: nil,
            message: "페이지를 불러올 수 없습니다. 네트워크를 확인해 주세요.",
            preferredStyle: .alert
        )
        
        let confirmAction = UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.close()
        }
        
        alert.addAction(confirmAction)
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func stopTimerAndHideActivityIndicator() {
        pageLoadTimeoutTimer?.invalidate()
        pageLoadTimeoutTimer = nil
        
        activityIndicatorView?.removeFromSuperview()
        activityIndicatorView = nil
    }
}

extension AmazingWebViewController: WKNavigationDelegate, WKUIDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
        stopTimerAndHideActivityIndicator()
        if failedToLoad {
            webView.isHidden = true
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        
        alertToClose()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        alertToClose()
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        self.handleClick(forNavigationAction: navigationAction, decisionHandler: nil)
        return nil
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        self.handleClick(forNavigationAction: navigationAction, decisionHandler: decisionHandler)
    }
    
    func handleClick(forNavigationAction navigationAction: WKNavigationAction, decisionHandler: ((WKNavigationActionPolicy) -> Void)?) {
        if navigationAction.navigationType == .linkActivated || navigationAction.navigationType == .other,
           let url = navigationAction.request.url, !isAmazingURL(url) {
            // a 태그 클릭을 했는데, 어메이징 url이 아니어서 외부 브라우저를 열어야 할 때.
            decisionHandler?(.cancel)
            
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
            return
        }
        
        if let url = navigationAction.request.url,
           url.scheme != "http" && url.scheme != "https" {
            // http, https scheme 모두 아닐 때. 예치금 충전 시, 결제 앱을 열 때
            decisionHandler?(.cancel)
            
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
            return
        }
        
        decisionHandler?(.allow)
    }
}

extension AmazingWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "adrop":
            guard let body = message.body as? NSDictionary else { return }
            guard let action = body["action"] as? String else { return }
            
            switch action {
            case "close":
                close()
            default:
                break;
            }
        default:
            break
        }
    }
}

extension AmazingWebViewController: WKScriptMessageHandlerWithReply {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
        switch message.name {
        case "bridge":
            guard let body = message.body as? NSDictionary else { return }
            guard let sig = body["sig"] as? String else { return }
            
            switch sig {
            case "getAppVersion":
                let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                let sdkVersion = "1.4.0" // Do not modify
                replyHandler("iOS/\(sdkVersion)/\(appVersion)", nil)
                break
            case "haptic":
                guard let payload = body["payload"] as? [String: Any] else { return }
                // 'light' | 'medium' | 'heavy' | 'selection' | 'vibrate'
                guard let type = payload["type"] as? String else { return }
                switch type {
                case "light":
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                case "medium":
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                case "heavy":
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                case "selection":
                    UISelectionFeedbackGenerator().selectionChanged()
                case "vibrate":
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                case "soft":
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                case "rigid":
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                default:
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            default:
                break
            }
        default:
            break
        }
    }
}
