/*   Copyright 2018-2019 Prebid.org, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import WebKit
import StoreKit

public class PrebidSKAdNetworkHelper {
    
    private weak var viewController: UIViewController?
    private weak var wkWebView: WKWebView?
    private var prebidSKAdNetworkData: PrebidSKAdNetworkData?
    private var pollingTimer: Timer?
    
    public init() {
        NotificationCenter.default.addObserver(self, selector: #selector(onAppBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onAppForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    deinit {
        stopPollingTimer()
        NotificationCenter.default.removeObserver(self)
    }

    @available(iOS 14.0, *)
    @objc
    public func subscribeOnAdClicked(viewController: UIViewController, adView: UIView) {
        
        self.viewController = viewController
        
        let view = AdViewUtils.findView(adView) { (subView) -> Bool in
            return AdViewUtils.isWKWebView(subView)
        }
        
        guard let wkWebView = view as? WKWebView else {
            Log.warn("view doesn't contain WKWebView")
            return
            
        }
        
        AdViewUtils.findIdInWebViewAsync(wkWebView: wkWebView, success: { (webViewId) in
            self.wkWebView = wkWebView
            
            guard let webViewId = webViewId else {
                Log.error("WKWebView doesn't contain id")
                return
            }
                
            let savedValuesDict = CacheManager.shared.savedValuesDict
            for (key, value) in savedValuesDict {
                
                let response = Utils.shared.getDictionaryFromString(value)!
                
                guard let ext = response["ext"] as? [AnyHashable : Any],
                   let prebid = ext["prebid"] as? [AnyHashable : Any],
                   let targeting = prebid["targeting"] as? [AnyHashable : Any],
                   let hbCacheId = targeting["hb_cache_id"] as? String else {
                    
                    continue
                }
                
                guard (hbCacheId == webViewId) else {
                    continue
                }
                
                guard let skadn = ext["skadn"] as? [AnyHashable : Any],
                      let itunesitem = skadn["itunesitem"] as? String,
                      let network = skadn["network"] as? String,
                      let campaign = skadn["campaign"] as? String,
                      let timestamp = skadn["timestamp"] as? String,
                      let nonce = skadn["nonce"] as? String,
                      let signature = skadn["signature"] as? String,
                      let sourceapp = skadn["sourceapp"] as? String,
                      let version = skadn["version"] as? String
                      else {
                    
                    Log.warn("response doesn't contain SKAdNetwork params")
                    break
                }
                
                self.prebidSKAdNetworkData = PrebidSKAdNetworkData(itunesitem: itunesitem, network: network, campaign: campaign, timestamp: timestamp, nonce: nonce, signature: signature, sourceapp: sourceapp, version: version)
                    
                self.injectSKAdNetworkCodeInWebViewAsync(wkWebView: wkWebView)
                
                break
            }
            
        })
    }
    
    public func viewAppear() {
        startPollingTimer()
    }
    
    public func viewDisappear() {
        stopPollingTimer()
    }
    
    private func injectSKAdNetworkCodeInWebViewAsync(wkWebView: WKWebView) {
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { (timer) in
            wkWebView.evaluateJavaScript("document.readyState", completionHandler: { (readyStateJS: Any!, error: Error!) -> Void in
                guard error == nil else {
                    Log.error("\(error.localizedDescription)")
                    return
                }
                
                if let readyState = readyStateJS as? String, readyState == "complete" {
                    Log.info("ready")
                    timer.invalidate()

                    wkWebView.evaluateJavaScript(
                    """
                    var isClicked = false;

                    // window.open
                    window.open_ = window.open;
                    window.open = function(url) {
                        if (url.includes(\"//apps.apple.com\") || url.includes(\"//itunes.apple.com\")) {
                            
                            isClicked = true;
                            console.log(\"appstore ad is clicked\");
                        } else {

                            console.log(\"default window.open\");
                            window.open_(url)
                        }
                    }

                    // window.mraid.open
                    window.mraidOpen_ = window.mraid.open;
                    window.mraid.open = function(url) {
                        if (url.includes(\"//apps.apple.com\") || url.includes(\"//itunes.apple.com\")) {
                            
                            isClicked = true;
                            console.log(\"appstore ad is clicked via mraid\");
                        } else {

                            console.log(\"default window.mraid.open\");
                            window.mraidOpen_(url)
                        }
                    }

                    // href
                    document.querySelectorAll(\"a[target='_blank']\").forEach((element) => {
                        element.addEventListener(\"click\", (event) => {
                            event.preventDefault();

                            console.log(\"ad is clicked\");
                            window.open(element.href);
                        })
                    })
                    """
                    
                    ) { (result, error) in
                    
                        self.startPollingTimer()
                    }
                }
            })
        }
    }
    
    private func startPollingTimer() {
        guard prebidSKAdNetworkData != nil else {
            return
        }
        
        stopPollingTimer()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { (timer) in
            
            self.pollOnClick()
            
        }
    }
    
    private func pollOnClick() {
        guard let wkWebView = self.wkWebView else {
            self.stopPollingTimer()
            return
        }
        
        wkWebView.evaluateJavaScript("isClicked", completionHandler: { (isClickedJS: Any!, error: Error!) -> Void in
            guard error == nil else {
                Log.error("2:\(error.localizedDescription)")
                return
            }

            guard let isClicked = isClickedJS as? Bool, isClicked == true else {
                Log.info("\(isClickedJS!)")
                return
            }
            
            Log.info("\(isClicked)")
            wkWebView.evaluateJavaScript("isClicked = false", completionHandler: { (value: Any!, error: Error!) -> Void in })
            
            if #available(iOS 14.0, *) {
                self.presentSKStoreProductViewController()
            }
            
        })
    }
    
    private func stopPollingTimer() {
        pollingTimer?.invalidate()
    }
    
    @available(iOS 14.0, *)
    private func presentSKStoreProductViewController() {
        
        guard let viewController = viewController, let skAdNetworkData = prebidSKAdNetworkData else {
            stopPollingTimer()
            return
        }

        let adViewController = SKStoreProductViewController()
        
        adViewController.loadProduct(withParameters:[
            SKStoreProductParameterITunesItemIdentifier: NSNumber(value: Int(skAdNetworkData.itunesitem)!),
            
            SKStoreProductParameterAdNetworkIdentifier: skAdNetworkData.network,
            SKStoreProductParameterAdNetworkCampaignIdentifier: NSNumber(value: Int(skAdNetworkData.campaign)!),
            SKStoreProductParameterAdNetworkTimestamp: NSNumber(value: Int(skAdNetworkData.timestamp)!),
            SKStoreProductParameterAdNetworkNonce: NSUUID(uuidString: skAdNetworkData.nonce)!,
            SKStoreProductParameterAdNetworkAttributionSignature: skAdNetworkData.signature,
            SKStoreProductParameterAdNetworkSourceAppStoreIdentifier: NSNumber(value: Int(skAdNetworkData.sourceapp)!),
            SKStoreProductParameterAdNetworkVersion: skAdNetworkData.version
            
        ]) { (result, error) in
            guard error == nil else {
                Log.error("\(error!)")
                return
            }
        }
        
        viewController.present(adViewController, animated: true, completion: nil)
        
    }

    //MARK: - App state
    @objc
    private func onAppForeground() {
        Log.info("App foreground")

        guard let viewController = viewController else {
            Log.info("no viewController")
            
            stopPollingTimer()
            return
        }
            
        if viewController.viewIfLoaded?.window != nil {
            // viewController is visible
            Log.info("viewController is visible")
            
            startPollingTimer()
        } else {
            Log.info("viewController is notvisible")
        }
        
    }
    
    @objc
    private func onAppBackground() {
        print("App background")
        stopPollingTimer()
    }
    
    //MARK: Data objects
    private struct PrebidSKAdNetworkData {
        let itunesitem: String
        let network: String
        let campaign: String
        let timestamp: String
        let nonce: String
        let signature: String
        let sourceapp: String
        let version: String
    }
}

public final class AdViewUtils: NSObject {

    fileprivate static let innerHtmlScript = "document.body.innerHTML"
    private static let sizeValueRegexExpression = "[0-9]+x[0-9]+"
    private static let sizeObjectRegexExpression = "hb_size\\W+\(sizeValueRegexExpression)" //"hb_size\\W+[0-9]+x[0-9]+"
    
    private override init() {}
    
    @objc
    public static func findPrebidCreativeSize(_ adView: UIView, success: @escaping (CGSize) -> Void, failure: @escaping (Error) -> Void) {
        
        let view = self.findView(adView) { (subView) -> Bool in
            return isWKWebView(subView)
        }
        
        if let wkWebView = view as? WKWebView  {
            Log.debug("subView is WKWebView")
            self.findSizeInWebViewAsync(wkWebView: wkWebView, success: success, failure: failure)
            
        } else {
            warnAndTriggerFailure(PbFindSizeErrorFactory.noWKWebView, failure: failure)
        }
    }
    
    static func triggerSuccess(size: CGSize, success: @escaping (CGSize) -> Void) {
        success(size)
    }
    
    static func warnAndTriggerFailure(_ error: PbFindSizeError, failure: @escaping (PbFindSizeError) -> Void) {
        Log.warn(error.localizedDescription)
        failure(error)
    }
    
    static func findView(_ view: UIView, closure:(UIView) -> Bool) -> UIView? {
        if closure(view)  {
            return view
        } else {
            return recursivelyFindView(view, closure: closure)
        }
    }
    
    static func recursivelyFindView(_ view: UIView, closure:(UIView) -> Bool) -> UIView? {
        for subview in view.subviews {
            
            if closure(subview)  {
                return subview
            }
            
            if let result = recursivelyFindView(subview, closure: closure) {
                return result
            }
        }
        
        return nil
    }
    
    static func findSizeInWebViewAsync(wkWebView: WKWebView, success: @escaping (CGSize) -> Void, failure: @escaping (PbFindSizeError) -> Void) {
        
        wkWebView.evaluateJavaScript(AdViewUtils.innerHtmlScript, completionHandler: { (value: Any!, error: Error!) -> Void in
            
            if error != nil {
                self.warnAndTriggerFailure(PbFindSizeErrorFactory.getWkWebViewFailedError(message: error.localizedDescription), failure: failure)
                return
            }
            
            self.findSizeInHtml(body: value as? String, success: success, failure: failure)
        })
        
    }
    
    static func findIdInWebViewAsync(wkWebView: WKWebView, success: @escaping (String?) -> Void) {
        wkWebView.evaluateJavaScript(AdViewUtils.innerHtmlScript, completionHandler: { (htmlBody: Any!, error: Error!) -> Void in
            
            self.findIdInHtml(htmlBody: htmlBody as? String, success: success)
        })
    }
    
    static func findSizeInHtml(body: String?, success: @escaping (CGSize) -> Void, failure: @escaping (PbFindSizeError) -> Void) {
        let result = findSizeInHtml(body: body)
        
        if let size = result.size {
            triggerSuccess(size: size, success: success)
        } else if let error = result.error {
            warnAndTriggerFailure(error, failure: failure)
        } else {
            Log.error("The bouth values size and error are nil")
            warnAndTriggerFailure(PbFindSizeErrorFactory.unspecified, failure: failure)
        }
    }
    
    static func findSizeInHtml(body: String?) -> (size: CGSize?, error: PbFindSizeError?) {
        guard let htmlBody = body, !htmlBody.isEmpty else {
            return (nil, PbFindSizeErrorFactory.noHtml)
        }
        
        guard let hbSizeObject = findHbSizeObject(in: htmlBody) else {
            return (nil, PbFindSizeErrorFactory.noSizeObject)
        }
        
        guard let hbSizeValue = findHbSizeValue(in: hbSizeObject) else {
            return (nil, PbFindSizeErrorFactory.noSizeValue)
        }
        
        let maybeSize = stringToCGSize(hbSizeValue)
        if let size = maybeSize {
            return (size, nil)
        } else {
            return (nil, PbFindSizeErrorFactory.sizeUnparsed)
        }
    }
    
    static func findHbSizeObject(in text: String) -> String? {
        return matchAndCheck(regex: AdViewUtils.sizeObjectRegexExpression, text: text)
    }
    
    static func findHbIdObject(in text: String) -> String? {
        return matchAndCheck(regex: "ucTagData.uuid = \"(.*?)\"", text: text, rangeAt: 1)
    }
    
    static func findHbSizeValue(in hbSizeObject: String) -> String? {
        return matchAndCheck(regex: AdViewUtils.sizeValueRegexExpression, text: hbSizeObject)
    }
    
    static func findIdInHtml(htmlBody: String?, success: @escaping (String?) -> Void) {
        success(AdViewUtils.findIdInHtml(body: htmlBody))
    }
    
    static func findIdInHtml(body: String?) -> String? {
        if let htmlBody = body, !htmlBody.isEmpty, let idObject = findHbIdObject(in: htmlBody) {
            return idObject
        }

        return nil
    }
    
    static func isWKWebView(_ view: UIView) -> Bool {
        return view is WKWebView
    }
    
    static func matchAndCheck(regex: String, text: String, rangeAt: Int = 0) -> String? {
        let matched = matches(for: regex, in: text, rangeAt: rangeAt)
        
        if matched.isEmpty {
            return nil
        }
        
        let firstResult = matched[0]
        
        return firstResult
    }
    
    static func matches(for regex: String, in text: String, rangeAt: Int) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return results.map {
                String(text[Range($0.range(at: rangeAt), in: text)!])
            }
        } catch let error {
            Log.warn("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    static func stringToCGSize(_ size: String) -> CGSize? {
        
        let sizeArr = size.split{$0 == "x"}.map(String.init)
        guard sizeArr.count == 2 else {
            Log.warn("\(size) has a wrong format")
            return nil
        }
        
        let nsNumberWidth = NumberFormatter().number(from: sizeArr[0])
        let nsNumberHeight = NumberFormatter().number(from: sizeArr[1])
        
        guard let numberWidth = nsNumberWidth, let numberHeight = nsNumberHeight else {
            Log.warn("\(size) can not be converted to CGSize")
            return nil
        }
        
        let width = CGFloat(truncating: numberWidth)
        let height = CGFloat(truncating: numberHeight)
        
        let gcSize = CGSize(width: width, height: height)
        
        return gcSize
    }

}

//It is not possible to use Enum because of compatibility with Objective-C
final class PbFindSizeErrorFactory {
    
    private init() {}
    
    // MARK: - Platform's errors
    static let unspecifiedCode = 101
    
    // MARK: - common errors
    static let noWKWebViewCode = 111
    static let wkWebViewFailedCode = 126
    static let noHtmlCode = 130
    static let noSizeObjectCode = 140
    static let noSizeValueCode = 150
    static let sizeUnparsedCode = 160
    
    //MARK: - fileprivate and private zone
    fileprivate static let unspecified = getUnspecifiedError()
    fileprivate static let noWKWebView = getNoWKWebViewError()
    fileprivate static let noHtml = getNoHtmlError()
    fileprivate static let noSizeObject = getNoSizeObjectError()
    fileprivate static let noSizeValue = getNoSizeValueError()
    fileprivate static let sizeUnparsed = getSizeUnparsedError()
    
    private static func getUnspecifiedError() -> PbFindSizeError{
        return getError(code: unspecifiedCode, description: "Unspecified error")
    }
    
    private static func getNoWKWebViewError() -> PbFindSizeError {
        return getError(code: noWKWebViewCode, description: "The view doesn't include WKWebView")
    }
    
    fileprivate static func getWkWebViewFailedError(message: String) -> PbFindSizeError {
        return getError(code: wkWebViewFailedCode, description: "WKWebView error:\(message)")
    }
    
    private static func getNoHtmlError() -> PbFindSizeError {
        return getError(code: noHtmlCode, description: "The WebView doesn't have HTML")
    }
    
    private static func getNoSizeObjectError() -> PbFindSizeError {
        return getError(code: noSizeObjectCode, description: "The HTML doesn't contain a size object")
    }
    
    private static func getNoSizeValueError() -> PbFindSizeError {
        return getError(code: noSizeValueCode, description: "The size object doesn't contain a value")
    }
    
    private static func getSizeUnparsedError() -> PbFindSizeError {
        return getError(code: sizeUnparsedCode, description: "The size value has a wrong format")
    }
    
    private static func getError(code: Int, description: String) -> PbFindSizeError {
        return PbFindSizeError(domain: "com.prebidmobile.ios", code: code, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
