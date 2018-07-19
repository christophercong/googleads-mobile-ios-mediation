//
//  GADMAppLovinRtbBannerRenderer.m
//  Adapter
//
//  Created by Christopher Cong on 7/17/18.
//  Copyright © 2018 Google. All rights reserved.
//

#import "GADMAppLovinRtbBannerRenderer.h"
#import "GADMAdapterAppLovinUtils.h"
#import "GADMAdapterAppLovinConstant.h"

#import <AppLovinSDK/AppLovinSDK.h>

/// Banner Delegate.
@interface GADMAppLovinRtbBannerDelegate : NSObject <ALAdLoadDelegate, ALAdDisplayDelegate, ALAdViewEventDelegate>
@property (nonatomic, weak) GADMAppLovinRtbBannerRenderer *parentRenderer;
- (instancetype)initWithParentRenderer:(GADMAppLovinRtbBannerRenderer *)parentRenderer;
@end

@interface GADMAppLovinRtbBannerRenderer () <GADMediationBannerAd>

/// Data used to render an RTB banner ad.
@property (nonatomic, strong) GADMediationBannerAdConfiguration *adConfiguration;

/// Callback object to notify the Google Mobile Ads SDK if ad rendering succeeded or failed.
@property (nonatomic, copy) GADBannerRenderCompletionHandler renderCompletionHandler;

/// Delegate to notify the Google Mobile Ads SDK of banner presentation events.
@property (nonatomic, strong, nullable) id<GADMediationBannerAdEventDelegate> adEventDelegate;

/// Controlled Properties
@property (nonatomic, strong) ALSdk *sdk;
@property (nonatomic, strong) ALAdSize *adSize;
@property (nonatomic, strong) ALAdView *adView;

@end

@implementation GADMAppLovinRtbBannerRenderer

- (instancetype)initWithAdConfiguration:(GADMediationBannerAdConfiguration *)adConfiguration
                      completionHandler:(GADBannerRenderCompletionHandler)handler {
    self = [super init];
    if (self) {
        self.adConfiguration = adConfiguration;
        self.renderCompletionHandler = handler;
        
        // Convert requested size to AppLovin Ad Size.
        self.adSize = [GADMAdapterAppLovinUtils adSizeFromRequestedSize:adConfiguration.adSize];
        self.sdk = [GADMAdapterAppLovinUtils retrieveSDKFromCredentials:adConfiguration.credentials.settings];
    }
    return self;
}

- (void)loadAd {
    if (self.adSize) {
        // Create adview object
        self.adView = [[ALAdView alloc] initWithSdk:self.sdk size:self.adSize];
        
        GADMAppLovinRtbBannerDelegate *delegate = [[GADMAppLovinRtbBannerDelegate alloc] initWithParentRenderer:self];
        self.adView.adDisplayDelegate = delegate;
        self.adView.adEventDelegate = delegate;
        
        // Load ad
        [self.sdk.adService loadNextAdForAdToken:self.adConfiguration.bidResponse andNotify:delegate];
    } else {
        NSError *error = [NSError errorWithDomain:GADMAdapterAppLovinConstant.rtbErrorDomain
                                             code:kGADErrorMediationInvalidAdSize
                                         userInfo:@{
                                                    NSLocalizedFailureReasonErrorKey :
                                                        @"Failed to request banner with unsupported size"
                                                    }];
        self.renderCompletionHandler(nil, error);
    }
}

#pragma mark - GADMediationBannerAd

- (UIView *)view {
    return self.adView;
}

@end

@implementation GADMAppLovinRtbBannerDelegate

#pragma mark - Initialization

- (instancetype)initWithParentRenderer:(GADMAppLovinRtbBannerRenderer *)parentRenderer {
    self = [super init];
    if (self) {
        self.parentRenderer = parentRenderer;
    }
    return self;
}

#pragma mark - Ad Load Delegate

- (void)adService:(ALAdService *)adService didLoadAd:(ALAd *)ad {
    [GADMAdapterAppLovinUtils log:@"Banner did load ad: %@", ad.adIdNumber];
    
    self.parentRenderer.adEventDelegate = self.parentRenderer.renderCompletionHandler(self, nil);
    
    [self.parentRenderer.adView render:ad];
}

- (void)adService:(ALAdService *)adService didFailToLoadAdWithError:(int)code {
    [GADMAdapterAppLovinUtils log:@"Failed to load banner ad with error: %d", code];
    
    NSError *error = [NSError errorWithDomain:GADMAdapterAppLovinConstant.rtbErrorDomain
                                         code:[GADMAdapterAppLovinUtils toAdMobErrorCode:code]
                                     userInfo:nil];
    self.parentRenderer.renderCompletionHandler(nil, error);
}

#pragma mark - Ad Display Delegate

- (void)ad:(ALAd *)ad wasDisplayedIn:(UIView *)view {
    [GADMAdapterAppLovinUtils log:@"Banner displayed"];
    [self.parentRenderer.adEventDelegate reportImpression];
}

- (void)ad:(ALAd *)ad wasHiddenIn:(UIView *)view {
    [GADMAdapterAppLovinUtils log:@"Banner dismissed"];
}

- (void)ad:(ALAd *)ad wasClickedIn:(UIView *)view {
    [GADMAdapterAppLovinUtils log:@"Banner clicked"];
    [self.parentRenderer.adEventDelegate reportClick];
}

#pragma mark - Ad View Event Delegate

- (void)ad:(ALAd *)ad didPresentFullscreenForAdView:(ALAdView *)adView {
    [GADMAdapterAppLovinUtils log:@"Banner presented fullscreen"];
    [self.parentRenderer.adEventDelegate willPresentFullScreenView];
}

- (void)ad:(ALAd *)ad willDismissFullscreenForAdView:(ALAdView *)adView {
    [GADMAdapterAppLovinUtils log:@"Banner will dismiss fullscreen"];
    [self.parentRenderer.adEventDelegate willDismissFullScreenView];
}

- (void)ad:(ALAd *)ad didDismissFullscreenForAdView:(ALAdView *)adView {
    [GADMAdapterAppLovinUtils log:@"Banner did dismiss fullscreen"];
    [self.parentRenderer.adEventDelegate didDismissFullScreenView];
}

- (void)ad:(ALAd *)ad willLeaveApplicationForAdView:(ALAdView *)adView {
    [GADMAdapterAppLovinUtils log:@"Banner left application"];
    [self.parentRenderer.adEventDelegate willBackgroundApplication];
}

- (void)ad:(ALAd *)ad didFailToDisplayInAdView:(ALAdView *)adView withError:(ALAdViewDisplayErrorCode)code {
    [GADMAdapterAppLovinUtils log:@"Banner failed to display: %ld", code];
}

@end
