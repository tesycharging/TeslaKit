//
//  TeslaWebLoginViewContoller.swift
//  TeslaKit
//
//  Update by David Lüthi on 10.06.2021
//  based on code from Joao Nunes on 22/11/2020.
//  Copyright © 2022 David Lüthi. All rights reserved.
//

#if canImport(WebKit) && canImport(UIKit)
import WebKit
import UIKit
import SwiftUI

public class TeslaWebLoginViewController: UIViewController {
    var webView = WKWebView()
    private var continuation: CheckedContinuation<URL, Error>?

    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    init(url: URL) {
        super.init(nibName: nil, bundle: nil)
        webView.navigationDelegate = self
        webView.load(URLRequest(url: url))
    }

    override public func loadView() {
        view = webView
    }

    func result() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
}

extension TeslaWebLoginViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.absoluteString.starts(with: "https://auth.tesla.com/void/callback") {
            decisionHandler(.cancel)
            self.dismiss(animated: true) {
                self.continuation?.resume(returning: url)
            }
        } else {
            decisionHandler(.allow)
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.dismiss(animated: true) {
            self.continuation?.resume(throwing: TeslaError.authenticationFailed)
        }
    }
}

extension TeslaWebLoginViewController {
    static func removeCookies() {
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
            }
        }
    }
}

public struct WebLogin: UIViewControllerRepresentable {
    public typealias UIViewControllerType = TeslaWebLoginViewController
	public var teslaAPI: TeslaAPI
    public let action: () -> Void
    
    public init(teslaAPI: TeslaAPI, action: @escaping () -> Void) {
        self.teslaAPI = teslaAPI
        self.action = action
    }
	
    public func makeUIViewController(context: Context) -> TeslaWebLoginViewController {
        let (webloginViewController, result) = teslaAPI.authenticateWeb()
        guard let safeWebloginViewController = webloginViewController else {
            return TeslaWebLoginViewController(url: URL(string: "https://www.tesla.com")!)
        }
        
        Task { @MainActor in
            do {
                _ = try await result()
                self.action()
            } catch let error {
                print("Authentication failed: \(error)")
            }
        }
        return safeWebloginViewController
        
    }

    public func updateUIViewController(_ uiViewController: TeslaWebLoginViewController, context: Context) {
    }
}
#endif

