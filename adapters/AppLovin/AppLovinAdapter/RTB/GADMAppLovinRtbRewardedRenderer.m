//
//  GADMAppLovinRtbRewardedRenderer.m
//  Adapter
//
//  Created by Christopher Cong on 7/17/18.
//  Copyright © 2018 Google. All rights reserved.
//

#import "GADMAppLovinRtbRewardedRenderer.h"
#import "GADMAdapterAppLovinUtils.h"
#import "GADMAdapterAppLovinConstant.h"
#import "GADMAdapterAppLovinExtras.h"

#import <AppLovinSDK/AppLovinSDK.h>

/// Rewarded Delegate.
@interface GADMAppLovinRtbRewardedDelegate : NSObject <ALAdLoadDelegate, ALAdDisplayDelegate, ALAdVideoPlaybackDelegate>
@property (nonatomic, weak) GADMAppLovinRtbRewardedRenderer *parentRenderer;
- (instancetype)initWithParentRenderer:(GADMAppLovinRtbRewardedRenderer *)parentRenderer;
@end

/// Rewarded Ad Reward Delegate.
@interface GADMAppLovinRtbRewardedAdRewardDelegate : NSObject <ALAdRewardDelegate>
@property (nonatomic, weak) GADMAppLovinRtbRewardedRenderer *parentRenderer;
- (instancetype)initWithParentRenderer:(GADMAppLovinRtbRewardedRenderer *)parentRenderer;
@end

@interface GADMAppLovinRtbRewardedRenderer () <GADMediationRewardedAd>

/// Data used to render an RTB rewarded ad.
@property (nonatomic, strong) GADMediationRewardedAdConfiguration *adConfiguration;

/// Callback object to notify the Google Mobile Ads SDK if ad rendering succeeded or failed.
@property (nonatomic, copy) GADRewardedRenderCompletionHandler renderCompletionHandler;

/// Delegate to notify the Google Mobile Ads SDK of rewarded presentation events.
@property (nonatomic, strong, nullable) id<GADMediationRewardedAdEventDelegate> adEventDelegate;

/// Controlled Properties
@property (nonatomic, strong) ALSdk *sdk;
@property (nonatomic, strong) ALIncentivizedInterstitialAd *incentivizedAd;
@property (nonatomic, strong) ALAd *ad;
@property (nonatomic, assign) BOOL fullyWatched;
@property (nonatomic, strong) GADAdReward *reward;

@end

@implementation GADMAppLovinRtbRewardedRenderer

- (instancetype)initWithAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                      completionHandler:(GADRewardedRenderCompletionHandler)handler {
    self = [super init];
    if (self) {
        self.adConfiguration = adConfiguration;
        self.renderCompletionHandler = handler;
        
        self.sdk = [GADMAdapterAppLovinUtils retrieveSDKFromCredentials:adConfiguration.credentials.settings];
    }
    return self;
}

- (void)loadAd {
    // Create rewarded video object
    self.incentivizedAd = [[ALIncentivizedInterstitialAd alloc] initWithSdk:self.sdk];
    
    GADMAppLovinRtbRewardedDelegate *delegate = [[GADMAppLovinRtbRewardedDelegate alloc] initWithParentRenderer:self];
    self.incentivizedAd.adDisplayDelegate = delegate;
    self.incentivizedAd.adVideoPlaybackDelegate = delegate;
    
    // Load ad
    [self.sdk.adService loadNextAdForAdToken:self.adConfiguration.bidResponse andNotify:delegate];
}

#pragma mark - GADMediationRewardedAd

- (void)presentFromViewController:(UIViewController *)viewController {
    // Update mute state
    GADMAdapterAppLovinExtras *extras = self.adConfiguration.extras;
    self.sdk.settings.muted = extras.muteAudio;
    
    GADMAppLovinRtbRewardedDelegate *rewardDelegate = [[GADMAppLovinRtbRewardedDelegate alloc] initWithParentRenderer:self];
    [self.incentivizedAd showOver:[UIApplication sharedApplication].keyWindow
                         renderAd:self.ad
                        andNotify:rewardDelegate];
}

@end

@implementation GADMAppLovinRtbRewardedDelegate

#pragma mark - Initialization

- (instancetype)initWithParentRenderer:(GADMAppLovinRtbRewardedRenderer *)parentRenderer {
    self = [super init];
    if (self) {
        self.parentRenderer = parentRenderer;
    }
    return self;
}

#pragma mark - Ad Load Delegate

- (void)adService:(ALAdService *)adService didLoadAd:(ALAd *)ad {
    [GADMAdapterAppLovinUtils log:@"Rewarded video did load ad: %@", ad.adIdNumber];
    
    self.parentRenderer.ad = ad;
    
    self.parentRenderer.adEventDelegate = self.parentRenderer.renderCompletionHandler(self, nil);
}

- (void)adService:(ALAdService *)adService didFailToLoadAdWithError:(int)code {
    [GADMAdapterAppLovinUtils log:@"Failed to load rewarded video with error: %d", code];
    
    NSError *error = [NSError errorWithDomain:GADMAdapterAppLovinConstant.rtbErrorDomain
                                         code:[GADMAdapterAppLovinUtils toAdMobErrorCode:code]
                                     userInfo:nil];
    self.parentRenderer.renderCompletionHandler(nil, error);
}

#pragma mark - Ad Display Delegate

- (void)ad:(ALAd *)ad wasDisplayedIn:(UIView *)view {
    [GADMAdapterAppLovinUtils log:@"Rewarded video displayed"];
    [self.parentRenderer.adEventDelegate reportImpression];
}

- (void)ad:(ALAd *)ad wasHiddenIn:(UIView *)view {
    [GADMAdapterAppLovinUtils log:@"Rewarded video hidden"];
    
    if (self.parentRenderer.fullyWatched && self.parentRenderer.reward) {
        [self.parentRenderer.adEventDelegate didRewardUserWithReward:self.parentRenderer.reward];
    }
    
    [self.parentRenderer.adEventDelegate willDismissFullScreenView];
    [self.parentRenderer.adEventDelegate didDismissFullScreenView];
    
    // Clear states in the case this delegate gets re-used in the future.
    self.parentRenderer.fullyWatched = NO;
    self.parentRenderer.reward = nil;
}

- (void)ad:(ALAd *)ad wasClickedIn:(UIView *)view {
    [GADMAdapterAppLovinUtils log:@"Rewarded video clicked"];
    [self.parentRenderer.adEventDelegate reportClick];
    [self.parentRenderer.adEventDelegate willBackgroundApplication];
}

#pragma mark - Video Playback Delegate

- (void)videoPlaybackBeganInAd:(ALAd *)ad {
    [GADMAdapterAppLovinUtils log:@"Rewarded video playback began"];
    [self.parentRenderer.adEventDelegate didStartPlayingVideo];
}

- (void)videoPlaybackEndedInAd:(ALAd *)ad
             atPlaybackPercent:(NSNumber *)percentPlayed
                  fullyWatched:(BOOL)wasFullyWatched {
    [GADMAdapterAppLovinUtils log:@"Rewarded video playback ended at playback percent: %lu%%",
     percentPlayed.unsignedIntegerValue];
    [self.parentRenderer.adEventDelegate didEndVideo];
}

@end

@implementation GADMAppLovinRtbRewardedAdRewardDelegate

#pragma mark - Initialization

- (instancetype)initWithParentRenderer:(GADMAppLovinRtbRewardedRenderer *)parentRenderer {
    self = [super init];
    if (self) {
        self.parentRenderer = parentRenderer;
    }
    return self;
}

#pragma mark - Reward Delegate

- (void)rewardValidationRequestForAd:(ALAd *)ad
          didExceedQuotaWithResponse:(NSDictionary *)response {
    [GADMAdapterAppLovinUtils log:@"Rewarded video validation request for ad did exceed quota with response: %@", response];
}

- (void)rewardValidationRequestForAd:(ALAd *)ad didFailWithError:(NSInteger)responseCode {
    [GADMAdapterAppLovinUtils log:@"Rewarded video validation request for ad failed with error code: %d", responseCode];
}

- (void)rewardValidationRequestForAd:(ALAd *)ad wasRejectedWithResponse:(NSDictionary *)response {
    [GADMAdapterAppLovinUtils log:@"Rewarded video validation request was rejected with response: %@", response];
}

- (void)userDeclinedToViewAd:(ALAd *)ad {
    [GADMAdapterAppLovinUtils log:@"User declined to view rewarded video"];
}

- (void)rewardValidationRequestForAd:(ALAd *)ad didSucceedWithResponse:(NSDictionary *)response {
    NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithString:response[@"amount"]];
    NSString *currency = response[@"currency"];
    
    [GADMAdapterAppLovinUtils log:@"Rewarded %@ %@", amount, currency];
    
    self.parentRenderer.reward = [[GADAdReward alloc] initWithRewardType:currency rewardAmount:amount];
}

@end
