//
//  TeslaWebLoginViewContoller.swift
//  TeslaSwift
//
//  Created by João Nunes on 22/11/2020.
//  Copyright © 2020 Joao Nunes. All rights reserved.
//

#if canImport(WebKit) && canImport(UIKit)
import WebKit

public class TeslaWebLoginViewController: UIViewController {
    var webView = WKWebView()
    var result: ((Result<URL, Error>) -> ())?

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
}

extension TeslaWebLoginViewController: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        if let url = navigationAction.request.url, url.absoluteString.starts(with: "https://auth.tesla.com/void/callback")  {
            //AppDelegate.sharedInstance.applicationHandle(url: url)
            decisionHandler(.cancel)
            self.dismiss(animated: true, completion: nil)
            self.result?(Result.success(url))
        } else {
            decisionHandler(.allow)
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.result?(Result.failure(TeslaError.authenticationFailed))
        self.dismiss(animated: true, completion: nil)
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
#endif

