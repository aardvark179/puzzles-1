//
//  GameHelpController.swift
//  Puzzles
//
//  Created by Duncan MacGregor on 09/03/2020.
//  Copyright © 2020 Greg Hewgill. All rights reserved.
//

import Foundation
import UIKit

class GameHelpController: UIViewController, UIWebViewDelegate {
    let file: String
    var webview: UIWebView?
    var backButton: UIBarButtonItem?
    var forwardButton: UIBarButtonItem?
    
    init(file: String) {
        self.file = file
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        webview = UIWebView.init()
        self.view = webview
        webview?.delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftItemsSupplementBackButton = true
        backButton = UIBarButtonItem(image: UIImage(contentsOfFile: "help-back.png"), style: .plain, target: webview, action: #selector(UIWebView.goBack))
        forwardButton = UIBarButtonItem(image: UIImage(contentsOfFile: "help-forward.png"), style: .plain, target: webview, action: #selector(UIWebView.goForward))
        navigationItem.leftBarButtonItems = [ backButton!, forwardButton! ]
        webview?.loadRequest(URLRequest(url: URL(fileURLWithPath: Bundle.main.path(forResource: file, ofType: nil)!)))
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        backButton?.isEnabled = webView.canGoBack
        forwardButton?.isEnabled = webView.canGoForward
        if ((webView.request?.url?.scheme == "file") &&
            (webView.request?.url?.lastPathComponent == "help.html")) {
            webView.stringByEvaluatingJavaScript(from: String(format: "document.getElementById('version').innerHTML = '%@';", (Bundle.main.infoDictionary?["CFBUndleVersion"])! as! NSString))
        }
    }
}
