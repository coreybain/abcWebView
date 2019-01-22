//
//  WebViewController.swift
//  WebViewFramework
//
//  Created by Corey Baines on 22/1/19.
//  Copyright © 2019 Corey Baines. All rights reserved.
//

import Foundation
import UIKit
import WebKit

var DEVICE_IPAD = UIDevice.current.userInterfaceIdiom == .pad
var DEVICE_LANDSCAPE = UIApplication.shared.statusBarOrientation == .landscapeLeft || UIApplication.shared.statusBarOrientation == .landscapeRight

public class WebViewController: UIViewController, WKUIDelegate, UIScrollViewDelegate, WVNavDelegate {
    
    //MARK: Variables
    // Controller context
    private var WVControllerContext = 0
    
    //View variables
    private weak var navigationBar: UINavigationBar?
    private weak var toolbar: UIToolbar?
    private weak var navigationBarSuperView: UIView?
    private var webView: WebView?
    
    //Support Variables
    private var url: URL?
    private var URL: NSURL?
    private var supportedNavTools: WVNavTools?
    private var supportedActions: WVNavActions?
    private var supportedPrompts: WVNavPrompt?
    private var backwardLongPress: UILongPressGestureRecognizer?
    private var forwardLongPress: UILongPressGestureRecognizer?
    private var showLoadingProgress: Bool = false
    private var hideBarsWithGestures: Bool = false
    private var completedInitialLoad: Bool = false
    
    //Styling for the navbar
    private var navColor:UIColor?
    private var navTextColor:UIColor?
    
    //MARK: Toolbar Buttons
    //Toolbar buttons for WebView control
    private lazy var backBarButtonItem: UIBarButtonItem = {
        var backButton = UIBarButtonItem()
        if let style = UIBarButtonItem.Style(rawValue: 0) {
            backButton = UIBarButtonItem(image: UIImage(named: "buttonBack", in: Bundle(for: WebViewController.self), compatibleWith: nil), landscapeImagePhone: nil, style: style, target: self, action: #selector(goBackward(_:)))
        }
        backButton.accessibilityLabel = NSLocalizedString("Backward", tableName: "WebViewController", bundle: Bundle.main, value: "", comment: "Button to return to previous page in web view")
        backButton.isEnabled = false
        return backButton
    }()
    
    private lazy var forwardBarButtonItem: UIBarButtonItem = {
        var forwardButton = UIBarButtonItem()
        if let style = UIBarButtonItem.Style(rawValue: 0) {
            forwardButton = UIBarButtonItem(image: UIImage(named: "buttonForward", in: Bundle(for: WebViewController.self), compatibleWith: nil), landscapeImagePhone: nil, style: style, target: self, action: #selector(goForward(_:)))
        }
        forwardButton.accessibilityLabel = NSLocalizedString("Forward", tableName: "WebViewController", bundle: Bundle.main, value: "", comment: "Button to return to previous page in web view after going backwards")
        forwardButton.isEnabled = false
        return forwardButton
    }()
    
    private lazy var stateBarButtonItem: UIBarButtonItem = {
        var stateButton = UIBarButtonItem()
        if let style = UIBarButtonItem.Style(rawValue: 0) {
            stateButton = UIBarButtonItem(image: UIImage(named: "buttonReload", in: Bundle(for: WebViewController.self), compatibleWith: nil), landscapeImagePhone: nil, style: style, target: self, action: #selector(webView!.reload))
        }
        return stateButton
    }()
    
    private lazy var actionBarButtonItem: UIBarButtonItem = {
        var actionButton = UIBarButtonItem()
        if let style = UIBarButtonItem.Style(rawValue: 0) {
            actionButton = UIBarButtonItem(image: UIImage(named: "buttonAction", in: Bundle(for: WebViewController.self), compatibleWith: nil), landscapeImagePhone: nil, style: style, target: self, action: #selector(presentActivityController(_:)))
        }
        actionButton.accessibilityLabel = NSLocalizedString("Forward", tableName: "WebViewController", bundle: Bundle.main, value: "", comment: "Button to return to previous page in web view after going backwards")
        actionButton.isEnabled = false
        return actionButton
    }()
    
    private lazy var progressView:UIProgressView = {
        let lineHeight: CGFloat = 2.0
        let frame = CGRect(x: 0, y: navigationController!.navigationBar.bounds.height - lineHeight, width: navigationController!.navigationBar.bounds.width, height: lineHeight)
        var progress = UIProgressView(frame: frame)
        progress.trackTintColor = UIColor.clear
        progress.alpha = 0.0
        return progress
        
    }()
    
    //initalizers for main content connections
    convenience init() {
        self.init(nibName:nil, bundle:nil)
    }
    
    public convenience init(url URL: URL) {
        self.init()
        self.url = URL
    }
    
    public func setNavColor(color: UIColor) {
        navColor = color
    }
    
    public func setNavTextColor(color: UIColor) {
        navTextColor = color
    }
    
    //This function creates the main view initalizing the toolbar/buttons and connection all requires views
    private func setupView() {
        supportedNavTools = WVNavTools.wvNavToolAll
        supportedActions = WVNavActions.wvNavActionAll
        supportedPrompts = WVNavPrompt.all
        showLoadingProgress = true
        hideBarsWithGestures = true
        
        webView = WebView(frame: self.view.bounds)
        
        let webConfiguration = WKWebViewConfiguration()
        webView = WebView(frame: .zero, configuration: webConfiguration)
        
        webView?.backgroundColor = .white
        webView?.allowsBackForwardNavigationGestures = true
        webView?.uiDelegate = self
        webView?.navigationDelegate = self
        webView?.setNavDelegate(self)
        webView?.scrollView.delegate = self
        webView?.addObserver(self, forKeyPath: "loading", options: .new, context: UnsafeMutableRawPointer(&WVControllerContext))
        webView?.scrollView.contentInset = UIEdgeInsets(top: 82, left: 0,bottom: 0, right: 0)
        
        self.view = webView
        completedInitialLoad  = false
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        if let color = navColor {
            navigationController?.navigationBar.barTintColor = color
        }
        if let color = navTextColor {
            navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: color]
        }
        setupView()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !completedInitialLoad {
            UIView.performWithoutAnimation {
                self.setupToolbars()
                self.navigationController!.navigationBar.addSubview(progressView)
            }
            completedInitialLoad = true
        }
        if let view = webView {
            if view.url == nil {
                loadURL(url: self.url!)
            }
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        clearProgress(animated: animated)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        webView?.stopLoading()
    }
    
    //Remove all observers and other items when view is destroyed
    deinit {
        if hideBarsWithGestures {
            navigationBar!.removeObserver(self, forKeyPath: "hidden", context: UnsafeMutableRawPointer(&WVControllerContext))
            navigationBar!.removeObserver(self, forKeyPath: "center", context: UnsafeMutableRawPointer(&WVControllerContext))
            navigationBar!.removeObserver(self, forKeyPath: "alpha", context: UnsafeMutableRawPointer(&WVControllerContext))
        }
        webView?.removeObserver(self, forKeyPath: "loading", context: UnsafeMutableRawPointer(&WVControllerContext))
        
        backwardLongPress = nil
        forwardLongPress = nil
        
        webView?.scrollView.delegate = nil
        webView?.navDelegate = nil
        webView?.uiDelegate = nil
        webView?.scrollView.delegate = nil
        webView = nil
        url = nil
        navigationController?.setToolbarHidden(true, animated: false)
    }
    
    private func clearProgress(animated: Bool) {
        
        UIView.animate(withDuration: animated ? 0.25 : 0.0, animations: {
            self.progressView.alpha = 0
        }) { finished in
            self.progressView.removeFromSuperview()
        }
    }
    
    //FINALLY:: Load url
    func loadURL(url: URL) {
        let baseURL = NSURL(fileURLWithPath: (NSURL(fileURLWithPath: url.path).deletingLastPathComponent?.absoluteString)!, isDirectory: true)
        load(url, baseUrl: baseURL as URL)
    }
    
    //Confirm url type and begin render of page
    func load(_ url: URL, baseUrl: URL) {
        
        if url.isFileURL {
            do {
                let data = try Data(contentsOf: url)
                let htmlString = String(data: data, encoding: .utf8)
                if let html = htmlString {
                    webView?.loadHTMLString(html, baseURL: baseUrl)
                }
            } catch {
                
            }
        } else {
            let request = URLRequest(url: url)
            webView?.load(request)
        }
    }
    
    //Setup toolbar for ipad and iphone
    private func setupToolbars() {
        if DEVICE_IPAD {
            self.navigationItem.rightBarButtonItems = navigationToolItems().reversed()
        } else {
            toolbarItems = navigationToolItems()
        }
        
        toolbar = navigationController?.toolbar
        navigationBar = navigationController?.navigationBar
        navigationBarSuperView = navigationBar?.superview
        
        navigationController?.hidesBarsOnSwipe = false
        navigationController?.hidesBarsWhenKeyboardAppears = hideBarsWithGestures
        navigationController?.hidesBarsWhenVerticallyCompact = hideBarsWithGestures
        
        if hideBarsWithGestures {
            navigationBar?.addObserver(self, forKeyPath: "hidden", options: .new, context: UnsafeMutableRawPointer(&WVControllerContext))
            navigationBar?.addObserver(self, forKeyPath: "center", options: .new, context: UnsafeMutableRawPointer(&WVControllerContext))
            navigationBar?.addObserver(self, forKeyPath: "alpha", options: .new, context: UnsafeMutableRawPointer(&WVControllerContext))
        }
        
        if !DEVICE_IPAD && !navigationController!.isToolbarHidden && toolbarItems!.count > 0 {
            navigationController?.isToolbarHidden = false
        } else {
            navigationController?.setToolbarHidden(false, animated: false)
        }
    }
    
    //Show activity alert modal (thrown in for demonstation purposes)
    @objc func presentActivityController(_ sender: Any?) {
        if let view = webView {
            if view.url!.absoluteString == "" {
                return
            }
            presentActivityController(withItem: view.url!.absoluteString, andTitle: view.title, sender: sender)
        }
    }
    
    private func presentActivityController(withItem item: Any?, andTitle title: String?, sender: Any?) {
        if let name = title, let obj = item {
            let controller = UIActivityViewController(activityItems: [name, obj], applicationActivities: applicationActivities(forItem: item))
            controller.excludedActivityTypes = excludedActivityTypes(forItem: item)
            
            if let titleString = title {
                controller.setValue(titleString, forKey: "subject")
            }
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                controller.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
            }
            
            present(controller, animated: true, completion: nil)
        }
    }
    
    private func applicationActivities(forItem item: Any?) -> [UIActivity]? {
        let activities = [UIActivity]()
        
        if (item is UIImage) {
            return activities
        }
        return activities
    }
    
    private func excludedActivityTypes(forItem item: Any?) -> [UIActivity.ActivityType]? {
        var types = [UIActivity.ActivityType]()
        
        if !(item is UIImage) {
            types.append(contentsOf: [UIActivity.ActivityType.copyToPasteboard,
                                      .saveToCameraRoll,
                                      .postToFlickr,
                                      .print,
                                      .assignToContact])
            
        }
        if supportsAllActions() {
            return types
        }
        
        if let actions = supportedActions {
            if actions.rawValue  == 0 && WVNavActions.shareLink.rawValue == 0 {
                types.append(contentsOf: [UIActivity.ActivityType.mail,
                                          .message,
                                          .postToFacebook,
                                          .postToTwitter,
                                          .airDrop])
            }
        }
        
        if let actions = supportedActions {
            if actions.rawValue  == 0 && WVNavActions.wvNavActionReadLater.rawValue == 0 && (item is UIImage) {
                types.append(UIActivity.ActivityType.addToReadingList)
            }
        }
        
        return types
    }
    
    
    
    //MARK: WebView Controls
    @objc func goBackward(_ sender: Any?) {
        if let view = webView {
            if view.canGoBack {
                view.goBack()
            }
        }
    }
    
    @objc func goForward(_ sender: Any?) {
        if let view = webView {
            if view.canGoForward {
                view.goForward()
            }
        }
    }
    
    private func updateToolbar() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = webView!.isLoading
        
        backBarButtonItem.isEnabled = webView!.canGoBack
        forwardBarButtonItem.isEnabled = webView!.canGoForward
        
        actionBarButtonItem.isEnabled = !webView!.isLoading
        
        updateStateBarItem()
    }
    
    private func updateStateBarItem() {
        stateBarButtonItem.target = webView
        stateBarButtonItem.image = webView!.isLoading ? UIImage(named: "buttonStop", in: Bundle(for: WebViewController.self), compatibleWith: nil) : UIImage(named: "buttonReload", in: Bundle(for: WebViewController.self), compatibleWith: nil)
        stateBarButtonItem.landscapeImagePhone = nil
        stateBarButtonItem.action = webView!.isLoading ? #selector(webView!.stopLoading) : #selector(webView!.reload)
        stateBarButtonItem.accessibilityLabel = NSLocalizedString(webView?.isLoading != nil ? "Stop" : "Reload", tableName: "WebViewController", bundle: Bundle.main, value: "", comment: "Accessibility label button title")
        stateBarButtonItem.isEnabled = true
    }
    
    private func setLoadingError(error: Error) {
        switch error {
        case URLError.unknown, URLError.cancelled:
            return
        default:
            break
        }
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        
        let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context != UnsafeMutableRawPointer(&WVControllerContext) {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if (object as? UINavigationBar) != nil {
            if DEVICE_LANDSCAPE {
                return
            }
            if let chge = change {
                if let new = chge[NSKeyValueChangeKey.newKey] {
                    if let number = new as? NSNumber {
                        let newNumber = number.boolValue
                        
                        if (keyPath == "hidden") && newNumber && ((navigationBar?.center.y)! >= CGFloat(-2.0)) {
                            navigationBar?.isHidden = false
                            if navigationBar?.superview == nil {
                                navigationBarSuperView!.addSubview(navigationBar!)
                            }
                        }
                        if (keyPath == "center") {
                            var center: CGPoint = (new as AnyObject).cgPointValue
                            if center.y < -2.0 {
                                center.y = -2.0
                                navigationBar!.center = center
                                
                                UIView.beginAnimations("DZNNavigationBarAnimation", context: nil)
                                
                                for subview: UIView in navigationBar!.subviews {
                                    if subview != navigationBar!.subviews[0] {
                                        subview.alpha = 0.0
                                    }
                                }
                                UIView.commitAnimations()
                            }
                        }
                    }
                    
                }
            }
        }
        
        if (object as? WKWebView) != nil {
            if keyPath == "loading" {
                self.updateToolbar()
            }
        }
    }
}

//MARK: WebKit methods
extension WebViewController {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateStateBarItem()
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = webView.isLoading
    }
    
    func webView(_ webView: WebView?, didUpdateProgress progress: CGFloat) {
        if !showLoadingProgress {
            self.progressView.removeFromSuperview()
            return
        }
        
        if progressView.alpha == 0 && progress > 0.0 {
            progressView.progress = 0
            UIView.animate(withDuration: 0.2, animations: {
                self.progressView.alpha = 1.0
            })
        } else if progressView.alpha == 1.0 && progress == 1.0 {
            UIView.animate(withDuration: 0.2, animations: {
                self.progressView.alpha = 0.0
            }) { finished in
                self.progressView.progress = 0
            }
        }
        progressView.setProgress(Float(progress), animated: true)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if supportedPrompts!.rawValue > WVNavPrompt.none.rawValue {
            setTitle(title: webView.title)
        }
        updateStateBarItem()
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.setLoadingError(error: error)
        
        switch error {
        case URLError.cancelled:
            return
        default:
            break
        }
        setTitle(title: nil)
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame?.isMainFrame == nil {
            webView.load(navigationAction.request)
        }
        
        return nil
    }
    
    private func setTitle(title:String?) {
        
        if supportedPrompts == WVNavPrompt.none {
            return
        }
        
        let url = webView?.url?.absoluteString
        
        var label = navigationItem.titleView as? UILabel
        
        if label == nil {
            label = UILabel()
            label?.numberOfLines = 2
            label?.textAlignment = .center
            label?.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            navigationItem.titleView = label
        }
        
        let titleFont = UIFont.boldSystemFont(ofSize: 14.0)
        let urlFont = UIFont(name: titleFont.fontName, size: titleFont.pointSize - 2.0)
        var textColor = UIColor.black
        if let color = navTextColor {
            textColor = color
        }
        
        var text = ""
        
        if (title?.count ?? 0) > 0 && showNavTitle() {
            text += "\(title ?? "")"
            
            if (url?.count ?? 0) > 0 && showNavURL() {
                text += "\n"
            }
        }
        
        if (url?.count ?? 0) > 0 && showNavURL() {
            text += "\(url ?? "")"
        }
        
        let attributes = [
            NSAttributedString.Key.font: titleFont,
            NSAttributedString.Key.foregroundColor: textColor
        ]
        let attributedString = NSMutableAttributedString(string: text, attributes: attributes)
        let urlRange: NSRange = (text as NSString).range(of: url ?? "")
        
        if Int(urlRange.location) != NSNotFound && showNavTitle()  {
            if let font = urlFont {
                attributedString.addAttribute(.font, value: font, range: urlRange)
            }
        }
        
        label?.attributedText = attributedString
        label?.sizeToFit()
        
        var frame: CGRect? = label?.frame
        frame?.size.height = (navigationController?.navigationBar.frame.height)!
        label?.frame = frame ?? CGRect.zero
        
    }
}

//MARK: Nav Items
extension WebViewController {
    private func navigationToolItems() -> [UIBarButtonItem] {
        var items = [UIBarButtonItem]()
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        if (supportedNavTools!.rawValue & WVNavTools.wvNavToolBackward.rawValue) > 0 || supportsAllNavTools() {
            items.append(backBarButtonItem)
        }
        if (supportedNavTools!.rawValue & WVNavTools.wvNavToolForward.rawValue) > 0 || supportsAllNavTools() {
            if !DEVICE_IPAD {
                items.append(flexibleSpace)
            }
            items.append(forwardBarButtonItem)
        }
        if (supportedNavTools!.rawValue & WVNavTools.wvNavToolForward.rawValue) > 0 || supportsAllNavTools() {
            if !DEVICE_IPAD {
                items.append(flexibleSpace)
            }
            items.append(stateBarButtonItem)
        }
        if (supportedNavTools!.rawValue & WVNavTools.wvNavToolForward.rawValue) > 0 || supportsAllNavTools() {
            if !DEVICE_IPAD {
                items.append(flexibleSpace)
            }
            items.append(actionBarButtonItem)
        }
        
        return items
    }
    
    private func supportsAllNavTools() -> Bool {
        return (supportedNavTools == WVNavTools.wvNavToolAll) ? true : false
    }
    
    private func supportsAllActions() -> Bool {
        return (supportedActions == WVNavActions.wvNavActionAll) ? true : false
    }
    
    private func showNavTitle() -> Bool {
        if (supportedPrompts!.rawValue > 0 && WVNavPrompt.title.rawValue > 0) || supportedPrompts == WVNavPrompt.all {
            return true
        }
        return false
    }
    
    private func showNavURL() -> Bool {
        if (supportedPrompts!.rawValue > 0 && WVNavPrompt.url.rawValue > 0) || supportedPrompts == WVNavPrompt.all {
            return true
        }
        return false
    }
    
}

//MARK: Web View nav constants
// -- list of supported tools
struct WVNavTools : OptionSet {
    let rawValue: Int
    
    static let wvNavToolNone = WVNavTools(rawValue: -1)
    static let wvNavToolAll = WVNavTools(rawValue: 0)
    static let wvNavToolBackward = WVNavTools(rawValue: (1 << 0))
    static let wvNavToolForward = WVNavTools(rawValue: (1 << 1))
    static let wvNavToolStopReload = WVNavTools(rawValue: (1 << 2))
}
// -- list of supported actions
struct WVNavActions : OptionSet {
    let rawValue: Int
    
    static let wvNavActionAll = WVNavActions(rawValue: -1)
    static let wvNavActionNone = WVNavActions(rawValue: 0)
    static let shareLink = WVNavActions(rawValue: (1 << 0))
    static let wvNavActionCopyLink = WVNavActions(rawValue: (1 << 1))
    static let wvNavActionReadLater = WVNavActions(rawValue: (1 << 2))
    static let wvNavActionOpenSafari = WVNavActions(rawValue: (1 << 3))
    static let wvNavActionOpenChrome = WVNavActions(rawValue: (1 << 4))
}
// -- list of prompts supported by web view
struct WVNavPrompt : OptionSet {
    let rawValue: Int
    
    static let none = WVNavPrompt(rawValue: 0)
    static let title = WVNavPrompt(rawValue: (1 << 0))
    static let url = WVNavPrompt(rawValue: (1 << 1))
    static let all = WVNavPrompt(rawValue: 2)
}
