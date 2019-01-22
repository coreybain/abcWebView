//
//  WebView.swift
//  WebViewFramework
//
//  Created by Corey Baines on 22/1/19.
//  Copyright © 2019 Corey Baines. All rights reserved.
//

import Foundation
import WebKit

class WebView: WKWebView {
    
    weak var navDelegate: WVNavDelegate?
    
    
    public func setNavDelegate(_ delegate: WVNavDelegate?) {
        if delegate == nil || navDelegate != nil {
            removeObserver(self as NSObject, forKeyPath: NSStringFromSelector(#selector(getter: WebView.estimatedProgress)))
        }
        
        if delegate != nil {
            addObserver(self as NSObject, forKeyPath: NSStringFromSelector(#selector(getter: WebView.estimatedProgress)), options: [.old, .new], context: nil)
        }
        
        navDelegate = delegate
        
        super.navigationDelegate = delegate
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == NSStringFromSelector(#selector(getter: WebView.estimatedProgress)) {
            if let delegate = navDelegate {
                delegate.webView(self, didUpdateProgress: CGFloat(estimatedProgress))
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

protocol WVNavDelegate: WKNavigationDelegate {
    func webView(_ webView: WebView?, didUpdateProgress progress: CGFloat)
}
