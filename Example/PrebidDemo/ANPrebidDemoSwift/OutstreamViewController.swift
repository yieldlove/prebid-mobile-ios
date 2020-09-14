//
//  OutstreamViewController.swift
//  ANPrebidDemoSwift
//
//  Created by Punnaghai Puviarasu on 9/1/20.
//  Copyright © 2020 Prebid. All rights reserved.
//

import UIKit
import GoogleMobileAds
import MoPub
import PrebidMobile


class OutstreamViewController: UIViewController,GADBannerViewDelegate, MPAdViewDelegate{
        var adServerName: String = ""
        @IBOutlet var appBannerView: UIView!
    
        var amBanner: DFPBannerView!
        var mpBanner: MPAdView!
        let request = DFPRequest()
    
        private var adUnit: AdUnit!
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            setupPB(host: .Appnexus, accountId: "aecd6ef7-b992-4e99-9bb8-65e2d984e1dd", storedResponse: "sample_video_response")
            let adUnit = VideoAdUnit(configId: "2c0af852-a55d-49dc-a5ca-ef7e141f73cc", size: CGSize(width: 300, height: 250))

            let parameters = VideoBaseAdUnit.Parameters()
            parameters.mimes = ["video/mp4"]
            parameters.protocols = [Signals.Protocols.VAST_2_0]
            parameters.playbackMethod = [Signals.PlaybackMethod.AutoPlaySoundOff]
            parameters.placement = Signals.Placement.InBanner
            adUnit.parameters = parameters

            self.adUnit = adUnit
            
            if (adServerName == "DFP") {
                let customAdSize = GADAdSizeFromCGSize(CGSize(width: 300, height: 250))
                
                amBanner = DFPBannerView(adSize: customAdSize)
                amBanner.adUnitID = "/19968336/PrebidMobileValidator_Banner_All_Sizes"
                
                amBanner.backgroundColor = .red
                amBanner.rootViewController = self
                amBanner.delegate = self
                appBannerView.addSubview(amBanner)
                
                adUnit.fetchDemand(adObject: self.request) { [weak self] (resultCode: ResultCode) in
                    
                    guard let self = self else {
                        print("self is nil")
                        return
                    }
                    self.amBanner.load(self.request)
                }
                
            } else if (adServerName == "MoPub") {
                
                mpBanner = MPAdView(adUnitId: "08184aed0b874758b555100b98f562a4")
                mpBanner.frame = CGRect(x: 0, y: 0, width: 300, height: 250)
                mpBanner.delegate = self
                appBannerView.addSubview(mpBanner)
                // Do any additional setup after loading the view, typically from a nib.
                adUnit.fetchDemand(adObject: mpBanner) { [weak self] (resultCode: ResultCode) in
                    guard let self = self else {
                        print("self is nil")
                        return
                    }

                    self.mpBanner.loadAd(withMaxAdSize: kMPPresetMaxAdSizeMatchFrame)
                }

            }
            
        }
    
        func setupPB(host: PrebidHost, accountId: String, storedResponse: String) {
                Prebid.shared.prebidServerHost = host
                Prebid.shared.prebidServerAccountId = accountId
                Prebid.shared.storedAuctionResponse = storedResponse
        }
            
        override func didReceiveMemoryWarning() {
            super.didReceiveMemoryWarning()
            // Dispose of any resources that can be recreated.
        }
        
        func adViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("adViewDidReceiveAd")
            
            AdViewUtils.findPrebidCreativeSize(bannerView,
                                                success: { (size) in
                                                    guard let bannerView = bannerView as? DFPBannerView else {
                                                        return
                                                    }

                                                    bannerView.resize(GADAdSizeFromCGSize(size))

            },
                                                failure: { (error) in
                                                    print("error: \(error)");

            })
        }

        func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
                print("adView:didFailToReceiveAdWithError: \(error.localizedDescription)")
        }

        func adViewDidReceiveAd(_ bannerView: DFPBannerView) {
            print("adViewDidReceiveAd")
            
            self.amBanner.resize(bannerView.adSize)

        }

        /// Tells the delegate an ad request failed.
        func adView(_ bannerView: DFPBannerView,
                    didFailToReceiveAdWithError error: GADRequestError) {
            print("adView:didFailToReceiveAdWithError: \(error.localizedDescription)")
        }

        func adViewDidLoadAd(_ view: MPAdView!, adSize: CGSize) {
            print("adView:adViewDidLoadAd")
            //view.sizeToFit()
            
        }

        func viewControllerForPresentingModalView() -> UIViewController! {
            return self
        }

        func adView(_ view: MPAdView!, didFailToLoadAdWithError error: Error!) {
            print("adView:didFailToReceiveAdWithError: \(error.localizedDescription)")
        }
    }
