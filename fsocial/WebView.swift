//
//  WebView.swift
//  fsocial
//
//  Created by Mason Earl on 1/11/26.
//

import SwiftUI
import WebKit
import Combine

// MARK: - Shared Process Pool for Session Sharing
class WebViewProcessPool {
    static let shared = WKProcessPool()
}

// MARK: - WebView Coordinator
class WebViewCoordinator: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var currentURL: URL?
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var pageTitle: String = ""
    @Published var extractedContent: String = ""
    @Published var isMuted: Bool = true
    
    weak var webView: WKWebView?
    
    // MARK: - Audio Control
    func setMuted(_ muted: Bool) {
        isMuted = muted
        guard let webView = webView else { return }
        
        // Use JavaScript to mute/unmute all audio and video elements
        let script = muted ? """
            (function() {
                // Mute all video elements
                document.querySelectorAll('video').forEach(function(v) {
                    v.muted = true;
                    v.pause();
                });
                // Mute all audio elements
                document.querySelectorAll('audio').forEach(function(a) {
                    a.muted = true;
                    a.pause();
                });
                // Store muted state
                window._fsocialMuted = true;
            })();
        """ : """
            (function() {
                // Unmute all video elements (but don't auto-play)
                document.querySelectorAll('video').forEach(function(v) {
                    v.muted = false;
                });
                // Unmute all audio elements
                document.querySelectorAll('audio').forEach(function(a) {
                    a.muted = false;
                });
                // Store muted state
                window._fsocialMuted = false;
            })();
        """
        
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    // Inject mute script on page load if muted
    func injectMuteScriptIfNeeded() {
        if isMuted {
            setMuted(true)
        }
    }
    
    func goBack() {
        guard let webView = webView else { return }
        // Always try to go back - let WKWebView handle if it can't
        webView.goBack()
        // Update state after a short delay to ensure webView state is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateNavigationState()
        }
    }
    
    func goForward() {
        guard let webView = webView else { return }
        // Always try to go forward - let WKWebView handle if it can't
        webView.goForward()
        // Update state after a short delay to ensure webView state is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateNavigationState()
        }
    }
    
    func updateNavigationState() {
        guard let webView = webView else { return }
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        currentURL = webView.url
    }
    
    func reload() {
        webView?.reload()
    }
    
    func goHome(url: URL) {
        webView?.load(URLRequest(url: url))
    }
    
    func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        webView?.load(URLRequest(url: url))
    }
    
    func injectText(_ text: String) {
        // JavaScript to find reply box and insert text
        // First tries to click reply button, then injects text
        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let javascript = """
        (function() {
            var text = '\(escapedText)';
            
            // Helper to dispatch input events properly
            function dispatchInputEvents(element) {
                element.dispatchEvent(new Event('focus', { bubbles: true }));
                element.dispatchEvent(new Event('input', { bubbles: true }));
                element.dispatchEvent(new Event('change', { bubbles: true }));
            }
            
            // Try execCommand first (works for contenteditable)
            function tryExecCommand(element) {
                element.focus();
                // Select all existing content first
                var selection = window.getSelection();
                var range = document.createRange();
                range.selectNodeContents(element);
                selection.removeAllRanges();
                selection.addRange(range);
                // Insert the text
                var success = document.execCommand('insertText', false, text);
                if (success) {
                    dispatchInputEvents(element);
                    return true;
                }
                return false;
            }
            
            // Handle standard input/textarea
            function handleStandardInput(element) {
                element.focus();
                element.value = text;
                element.dispatchEvent(new Event('input', { bubbles: true }));
                element.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            }
            
            // Handle contenteditable (React/Draft.js style)
            function handleContentEditable(element) {
                element.focus();
                
                // Try execCommand first
                if (tryExecCommand(element)) {
                    return true;
                }
                
                // Fallback: use innerHTML with proper React event simulation
                element.innerHTML = '<span data-text="true">' + text + '</span>';
                dispatchInputEvents(element);
                
                // Also try to trigger React's internal handlers
                var nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value')?.set;
                if (nativeInputValueSetter) {
                    var hiddenTextarea = element.querySelector('textarea') || element.closest('[data-testid]')?.querySelector('textarea');
                    if (hiddenTextarea) {
                        nativeInputValueSetter.call(hiddenTextarea, text);
                        hiddenTextarea.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                }
                
                return true;
            }
            
            // Check active element first
            var activeElement = document.activeElement;
            if (activeElement) {
                if (activeElement.tagName === 'TEXTAREA' || activeElement.tagName === 'INPUT') {
                    return handleStandardInput(activeElement);
                }
                if (activeElement.isContentEditable || activeElement.getAttribute('contenteditable') === 'true') {
                    return handleContentEditable(activeElement);
                }
            }
            
            var hostname = window.location.hostname;
            
            // X/Twitter specific
            if (hostname.includes('x.com') || hostname.includes('twitter.com')) {
                // Try to find and click the reply button first
                var replyButton = document.querySelector('[data-testid="reply"]');
                if (replyButton && !document.querySelector('[data-testid="tweetTextarea_0"]')) {
                    replyButton.click();
                    // Wait for reply box to appear, then inject
                    setTimeout(function() {
                        var replyBox = document.querySelector('[data-testid="tweetTextarea_0"]') ||
                                       document.querySelector('[role="textbox"][contenteditable="true"]');
                        if (replyBox) {
                            replyBox.focus();
                            document.execCommand('insertText', false, text);
                            replyBox.dispatchEvent(new Event('input', { bubbles: true }));
                        }
                    }, 500);
                    return true;
                }
                
                // Reply box already open
                var xCompose = document.querySelector('[data-testid="tweetTextarea_0"]') || 
                               document.querySelector('[data-testid="tweetTextarea_0_label"]')?.querySelector('[contenteditable="true"]') ||
                               document.querySelector('[aria-label="Post text"]') ||
                               document.querySelector('[aria-label="Tweet text"]') ||
                               document.querySelector('[role="textbox"][contenteditable="true"]');
                if (xCompose) {
                    return handleContentEditable(xCompose);
                }
            }
            
            // X/Twitter fallback: find the compose box
            var xCompose = document.querySelector('[data-testid="tweetTextarea_0"]') || 
                           document.querySelector('[data-testid="tweetTextarea_0_label"]')?.querySelector('[contenteditable="true"]') ||
                           document.querySelector('[aria-label="Post text"]') ||
                           document.querySelector('[aria-label="Tweet text"]') ||
                           document.querySelector('[role="textbox"][contenteditable="true"]');
            if (xCompose) {
                return handleContentEditable(xCompose);
            }
            
            // Instagram specific
            if (hostname.includes('instagram.com')) {
                var instaComment = document.querySelector('textarea[aria-label*="comment"]') ||
                                   document.querySelector('textarea[placeholder*="comment"]') ||
                                   document.querySelector('textarea[placeholder*="Add a comment"]') ||
                                   document.querySelector('form textarea');
                if (instaComment) {
                    return handleStandardInput(instaComment);
                }
            }
            
            // Threads specific
            if (hostname.includes('threads.net')) {
                var threadsBox = document.querySelector('[contenteditable="true"]') ||
                                 document.querySelector('textarea');
                if (threadsBox) {
                    if (threadsBox.tagName === 'TEXTAREA') {
                        return handleStandardInput(threadsBox);
                    } else {
                        return handleContentEditable(threadsBox);
                    }
                }
            }
            
            // TikTok specific
            if (hostname.includes('tiktok.com')) {
                // TikTok comment box
                var tiktokComment = document.querySelector('[data-e2e="comment-input"]') ||
                                    document.querySelector('[contenteditable="true"]') ||
                                    document.querySelector('div[class*="DraftEditor"]') ||
                                    document.querySelector('textarea');
                if (tiktokComment) {
                    if (tiktokComment.tagName === 'TEXTAREA') {
                        return handleStandardInput(tiktokComment);
                    } else {
                        return handleContentEditable(tiktokComment);
                    }
                }
            }
            
            // Facebook specific
            if (hostname.includes('facebook.com')) {
                var fbComment = document.querySelector('[contenteditable="true"][role="textbox"]') ||
                                document.querySelector('[aria-label*="comment"]') ||
                                document.querySelector('[aria-label*="Write a comment"]') ||
                                document.querySelector('form [contenteditable="true"]');
                if (fbComment) {
                    return handleContentEditable(fbComment);
                }
            }
            
            // LinkedIn specific
            if (hostname.includes('linkedin.com')) {
                var linkedinBox = document.querySelector('[contenteditable="true"][role="textbox"]') ||
                                  document.querySelector('.ql-editor') ||
                                  document.querySelector('[data-placeholder]') ||
                                  document.querySelector('[aria-label*="Add a comment"]');
                if (linkedinBox) {
                    return handleContentEditable(linkedinBox);
                }
            }
            
            // Letterboxd specific
            if (hostname.includes('letterboxd.com')) {
                var letterboxdComment = document.querySelector('textarea#comment-text') ||
                                        document.querySelector('textarea[name="comment"]') ||
                                        document.querySelector('.comment-form textarea') ||
                                        document.querySelector('textarea');
                if (letterboxdComment) {
                    return handleStandardInput(letterboxdComment);
                }
            }
            
            // Goodreads specific
            if (hostname.includes('goodreads.com')) {
                var goodreadsComment = document.querySelector('textarea#comment_body') ||
                                       document.querySelector('textarea[name*="comment"]') ||
                                       document.querySelector('.userReviewContents textarea') ||
                                       document.querySelector('textarea');
                if (goodreadsComment) {
                    return handleStandardInput(goodreadsComment);
                }
            }
            
            // Generic fallback: find any visible contenteditable or textarea
            var editables = document.querySelectorAll('[contenteditable="true"], textarea:not([hidden])');
            for (var i = 0; i < editables.length; i++) {
                var el = editables[i];
                if (el.offsetParent !== null && el.offsetHeight > 0) {
                    if (el.tagName === 'TEXTAREA') {
                        return handleStandardInput(el);
                    } else {
                        return handleContentEditable(el);
                    }
                }
            }
            
            return false;
        })();
        """
        
        webView?.evaluateJavaScript(javascript) { _, error in
            if let error = error {
                print("JavaScript injection error: \(error)")
            }
        }
    }
    
    // MARK: - Extract Content from Page
    
    func extractPageContent(completion: @escaping (String) -> Void) {
        let javascript = """
        (function() {
            var content = '';
            
            // Platform-specific content extraction
            var hostname = window.location.hostname;
            
            // X/Twitter - get tweet content
            if (hostname.includes('x.com') || hostname.includes('twitter.com')) {
                // Get the main tweet being viewed or focused tweets
                var tweets = document.querySelectorAll('[data-testid="tweetText"]');
                var tweetTexts = [];
                tweets.forEach(function(tweet, index) {
                    if (index < 3) { // Get first 3 tweets visible
                        tweetTexts.push(tweet.innerText);
                    }
                });
                content = tweetTexts.join('\\n---\\n');
                
                // Also try to get the author
                var author = document.querySelector('[data-testid="User-Name"]');
                if (author) {
                    content = 'Author: ' + author.innerText + '\\n\\n' + content;
                }
            }
            
            // Instagram - get post caption or comments
            else if (hostname.includes('instagram.com')) {
                var caption = document.querySelector('h1') || document.querySelector('[class*="Caption"]');
                if (caption) {
                    content = caption.innerText;
                }
                // Get comments
                var comments = document.querySelectorAll('ul li span');
                var commentTexts = [];
                comments.forEach(function(c, i) {
                    if (i < 5 && c.innerText.length > 10) {
                        commentTexts.push(c.innerText);
                    }
                });
                if (commentTexts.length > 0) {
                    content += '\\n\\nComments:\\n' + commentTexts.join('\\n');
                }
            }
            
            // LinkedIn - get post content
            else if (hostname.includes('linkedin.com')) {
                var post = document.querySelector('.feed-shared-update-v2__description') ||
                           document.querySelector('[class*="update-components-text"]') ||
                           document.querySelector('.break-words');
                if (post) {
                    content = post.innerText;
                }
            }
            
            // Threads
            else if (hostname.includes('threads.net')) {
                var threadPost = document.querySelector('[class*="text"]');
                if (threadPost) {
                    content = threadPost.innerText;
                }
            }
            
            // TikTok - get video description
            else if (hostname.includes('tiktok.com')) {
                var desc = document.querySelector('[data-e2e="browse-video-desc"]') ||
                           document.querySelector('[class*="video-meta-caption"]');
                if (desc) {
                    content = desc.innerText;
                }
            }
            
            // Facebook
            else if (hostname.includes('facebook.com')) {
                var fbPost = document.querySelector('[data-ad-comet-preview="message"]') ||
                             document.querySelector('[class*="userContent"]');
                if (fbPost) {
                    content = fbPost.innerText;
                }
            }
            
            // Letterboxd - get film review content
            else if (hostname.includes('letterboxd.com')) {
                var filmTitle = document.querySelector('.headline-1') ||
                                document.querySelector('h1');
                var review = document.querySelector('.review .body-text') ||
                             document.querySelector('[class*="review-body"]') ||
                             document.querySelector('.truncate');
                if (filmTitle) {
                    content = 'Film: ' + filmTitle.innerText + '\\n\\n';
                }
                if (review) {
                    content += review.innerText;
                }
            }
            
            // Goodreads - get book review content
            else if (hostname.includes('goodreads.com')) {
                var bookTitle = document.querySelector('h1[data-testid="bookTitle"]') ||
                                document.querySelector('h1.Text__title1');
                var review = document.querySelector('.ReviewText__content') ||
                             document.querySelector('[class*="reviewText"]') ||
                             document.querySelector('.readable');
                if (bookTitle) {
                    content = 'Book: ' + bookTitle.innerText + '\\n\\n';
                }
                if (review) {
                    content += review.innerText;
                }
            }
            
            // Fallback - get visible text from main content area
            if (!content || content.length < 20) {
                var mainContent = document.querySelector('main') || 
                                  document.querySelector('article') ||
                                  document.querySelector('[role="main"]');
                if (mainContent) {
                    content = mainContent.innerText.substring(0, 1500);
                }
            }
            
            return content.substring(0, 2000);
        })();
        """
        
        webView?.evaluateJavaScript(javascript) { [weak self] result, error in
            DispatchQueue.main.async {
                if let content = result as? String, !content.isEmpty {
                    self?.extractedContent = content
                    completion(content)
                } else {
                    completion("")
                }
            }
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.isLoading = true
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.pageTitle = webView.title ?? ""
            // Update navigation state with a small delay to ensure webView state is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.updateNavigationState()
            }
            // Inject mute script if this tab should be muted
            self.injectMuteScriptIfNeeded()
        }
    }
    
    // MARK: - WKUIDelegate (for popups, alerts, new windows)
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle popup requests by loading in the same webView (important for login flows)
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let result = alert.runModal()
        completionHandler(result == .alertFirstButtonReturn)
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        DispatchQueue.main.async {
            // Update navigation state immediately when navigation commits
            self.updateNavigationState()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.updateNavigationState()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.updateNavigationState()
        }
    }
    
    // MARK: - LinkedIn Automation
    
    @Published var automationRunning = false
    private var automationWorkItem: DispatchWorkItem?
    
    func startLinkedInAutomation(interests: [String], keywords: [String], maxConnections: Int, delay: Double, completion: @escaping (Int, String?) -> Void) {
        automationRunning = true
        var connectionsMade = 0
        
        let interestsJSON = try! JSONSerialization.data(withJSONObject: interests)
        let interestsString = String(data: interestsJSON, encoding: .utf8) ?? "[]"
        let keywordsJSON = try! JSONSerialization.data(withJSONObject: keywords)
        let keywordsString = String(data: keywordsJSON, encoding: .utf8) ?? "[]"
        
        func executeStep() {
            guard automationRunning && connectionsMade < maxConnections else {
                automationRunning = false
                completion(connectionsMade, nil)
                return
            }
            
            let javascript = """
            (function() {
                var interests = \(interestsString);
                var keywords = \(keywordsString);
                
                // Scroll to load more profiles
                window.scrollTo(0, document.body.scrollHeight);
                
                // Find connect buttons - try multiple selectors
                var buttons = [];
                
                // Method 1: By text content
                Array.from(document.querySelectorAll('button')).forEach(function(btn) {
                    var text = btn.innerText.toLowerCase().trim();
                    if ((text === 'connect' || text.includes('connect')) && 
                        !text.includes('connected') && 
                        !text.includes('pending') &&
                        !text.includes('message')) {
                        buttons.push(btn);
                    }
                });
                
                // Method 2: By aria-label
                Array.from(document.querySelectorAll('button[aria-label*="Connect"], button[aria-label*="connect"]')).forEach(function(btn) {
                    if (!buttons.includes(btn)) {
                        buttons.push(btn);
                    }
                });
                
                // Method 3: By data attributes
                Array.from(document.querySelectorAll('button[data-control-name*="connect"]')).forEach(function(btn) {
                    if (!buttons.includes(btn)) {
                        buttons.push(btn);
                    }
                });
                
                if (buttons.length === 0) {
                    return JSON.stringify({ found: false, clicked: false });
                }
                
                // Find first matching button based on interests/keywords
                for (var i = 0; i < buttons.length; i++) {
                    var button = buttons[i];
                    
                    // Find parent profile card
                    var profileCard = button.closest('.entity-result__item, .reusable-search__result-container, .search-result');
                    
                    if (!profileCard) {
                        var parent = button.parentElement;
                        var attempts = 0;
                        while (parent && attempts < 8) {
                            if (parent.querySelector('.entity-result__title, .search-result__title, h3, [class*="name"]')) {
                                profileCard = parent;
                                break;
                            }
                            parent = parent.parentElement;
                            attempts++;
                        }
                    }
                    
                    if (profileCard) {
                        var profileText = profileCard.innerText.toLowerCase();
                        var matches = false;
                        
                        // If no filters, match all
                        if (interests.length === 0 && keywords.length === 0) {
                            matches = true;
                        } else {
                            // Check interests
                            for (var j = 0; j < interests.length; j++) {
                                if (profileText.includes(interests[j].toLowerCase())) {
                                    matches = true;
                                    break;
                                }
                            }
                            
                            // Check keywords
                            if (!matches) {
                                for (var j = 0; j < keywords.length; j++) {
                                    if (profileText.includes(keywords[j].toLowerCase())) {
                                        matches = true;
                                        break;
                                    }
                                }
                            }
                        }
                        
                        if (matches) {
                            // Scroll to button and click
                            button.scrollIntoView({ behavior: 'smooth', block: 'center' });
                            setTimeout(function() {
                                button.click();
                                
                                // Handle modal after a delay
                                setTimeout(function() {
                                    var sendBtn = document.querySelector('button[aria-label*="Send"], button[aria-label*="send"]');
                                    if (sendBtn && sendBtn.innerText.toLowerCase().includes('send')) {
                                        sendBtn.click();
                                    }
                                    
                                    var dismissBtn = document.querySelector('button[aria-label*="Dismiss"], button[aria-label*="Close"]');
                                    if (dismissBtn) {
                                        dismissBtn.click();
                                    }
                                }, 800);
                            }, 500);
                            
                            return JSON.stringify({ found: true, clicked: true });
                        }
                    }
                }
                
                return JSON.stringify({ found: false, clicked: false });
            })();
            """
            
            webView?.evaluateJavaScript(javascript) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self = self, self.automationRunning else {
                        completion(connectionsMade, nil)
                        return
                    }
                    
                    if let error = error {
                        self.automationRunning = false
                        completion(connectionsMade, "Error: \(error.localizedDescription)")
                        return
                    }
                    
                    var clicked = false
                    if let resultString = result as? String,
                       let data = resultString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        clicked = json["clicked"] as? Bool ?? false
                    }
                    
                    if clicked {
                        connectionsMade += 1
                        // Wait before next step
                        let workItem = DispatchWorkItem {
                            executeStep()
                        }
                        self.automationWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
                    } else {
                        // No more buttons found, stop
                        self.automationRunning = false
                        completion(connectionsMade, nil)
                    }
                }
            }
        }
        
        // Start the automation
        executeStep()
    }
    
    func stopLinkedInAutomation() {
        automationRunning = false
        automationWorkItem?.cancel()
        automationWorkItem = nil
    }
}

// MARK: - WebView (NSViewRepresentable)
struct WebView: NSViewRepresentable {
    let url: URL
    @ObservedObject var coordinator: WebViewCoordinator
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WebViewProcessPool.shared
        configuration.websiteDataStore = .default()
        
        // Enable JavaScript and modern web features
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences
        
        // Web page preferences for better compatibility
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = webpagePreferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator  // Important for login popups
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        
        // Use Chrome user agent for better compatibility with TikTok and Instagram
        // These platforms often block Safari/WebKit user agents
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        coordinator.webView = webView
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Ensure coordinator always has the webView reference
        if coordinator.webView !== nsView {
            coordinator.webView = nsView
            // Update navigation state when webView is set
            DispatchQueue.main.async {
                coordinator.updateNavigationState()
            }
        }
    }
}
