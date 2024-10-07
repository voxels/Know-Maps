//
//  GoogleBannerView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/4/24.
//

import SwiftUI
/*
import GoogleMobileAds

public struct BannerView: UIViewRepresentable {
    let adSize: GADAdSize
    
    init(_ adSize: GADAdSize) {
        self.adSize = adSize
    }
    
    public func makeUIView(context: Context) -> UIView {
        // Wrap the GADBannerView in a UIView. GADBannerView automatically reloads a new ad when its
        // frame size changes; wrapping in a UIView container insulates the GADBannerView from size
        // changes that impact the view returned from makeUIView.
        let view = UIView()
        view.addSubview(context.coordinator.bannerView)
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.bannerView.adSize = adSize
    }
    
    public func makeCoordinator() -> BannerCoordinator {
        return BannerCoordinator(self)
    }
}

public class BannerCoordinator: NSObject, GADBannerViewDelegate {
    
    private(set) lazy var bannerView: GADBannerView = {
        let banner = GADBannerView(adSize: parent.adSize)
        banner.adUnitID = "ca-app-pub-2394665159999622/4119047365"
        banner.load(GADRequest())
        banner.delegate = self
        return banner
    }()
    
    let parent: BannerView
    
    init(_ parent: BannerView) {
        self.parent = parent
    }
    
    // MARK: - GADBannerViewDelegate methods

    public func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
      print("DID RECEIVE AD.")
    }

    public func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
      print("FAILED TO RECEIVE AD: \(error.localizedDescription)")
    }
}
*/
