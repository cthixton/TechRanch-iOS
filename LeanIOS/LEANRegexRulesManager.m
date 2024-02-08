//
//  LEANRegexRulesManager.m
//  GonativeIO
//
//  Created by bld ai on 6/14/22.
//  Copyright © 2022 GoNative.io LLC. All rights reserved.
//

#import "LEANRegexRulesManager.h"
#import <SafariServices/SafariServices.h>
#import "GonativeIO-Swift.h"

@interface LEANRegexRulesManager()<SFSafariViewControllerDelegate>
@property (weak, nonatomic) LEANWebViewController *wvc;
@property NSArray<NSDictionary *> *regexRules;
@end

@implementation LEANRegexRulesManager

- (instancetype)initWithWvc:(LEANWebViewController *)wvc
{
    self = [super init];
    if (self) {
        self.wvc = wvc;
        [self initializeValues];
    }
    return self;
}

- (void)initializeValues {
    NSArray<NSDictionary *> *regexRules;
    [[GoNativeAppConfig sharedAppConfig] initializeRegexRules:&regexRules];
    self.regexRules = regexRules;
}

- (void)handleUrl:(NSURL *)url query:(NSDictionary*)query {
    if ([@"/set" isEqualToString:url.path]) {
        [self setRules:query[@"rules"]];
    }
}

- (void)setRules:(NSArray *)rules {
    NSArray *regexRules;
    [[GoNativeAppConfig sharedAppConfig] setNewRegexRules:rules regexRulesArray:&regexRules];
    self.regexRules = regexRules;
}

- (NSDictionary *)matchesWithUrlString:(NSString *)urlString {
    for (NSUInteger i = 0; i < self.regexRules.count; i++) {
        NSPredicate *predicate = self.regexRules[i][@"predicate"];
        NSString *mode = self.regexRules[i][@"mode"];
        
        if (![predicate isKindOfClass:[NSPredicate class]] || ![mode isKindOfClass:[NSString class]]) {
            continue;
        }
        
        @try {
            if ([predicate evaluateWithObject:urlString]) {
                return @{ @"matches": @YES, @"mode": mode };
            }
        }
        @catch (NSException* exception) {
            NSLog(@"Error in regex internal external: %@", exception);
        }
    }
    return @{ @"matches": @NO };
}

- (void)openExternalUrl:(NSURL *)url mode:(NSString *)mode {
    if ([mode isEqualToString:@"appbrowser"]) {
        SFSafariViewController *vc = [[SFSafariViewController alloc] initWithURL:url];
        vc.delegate = self;
        [self.wvc presentViewController:vc animated:YES completion:nil];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    });
}

- (BOOL)shouldHandleRequest:(NSURLRequest *)request {
    NSURL *url = [request URL];
    NSString *urlString = [url absoluteString];
    NSString* hostname = [url host];
    
    NSDictionary *matchResult = [self matchesWithUrlString:urlString];
    
    BOOL matchedRegex = [matchResult[@"matches"] boolValue];
    if (matchedRegex) {
        NSString *mode = matchResult[@"mode"];
        
        if ([mode isKindOfClass:[NSString class]] && ![mode isEqualToString:@"internal"]) {
            [self openExternalUrl:request.URL mode:mode];
            return NO;
        }
    } else  {
        NSString *initialHost = [GoNativeAppConfig sharedAppConfig].initialHost;
        
        if (![hostname isEqualToString:initialHost] && ![hostname hasSuffix:[@"." stringByAppendingString:initialHost]]) {
            [self openExternalUrl:request.URL mode:@"external"];
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - SFSafariViewControllerDelegate
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.wvc runJavascriptWithCallback:@"median_appbrowser_closed" data:nil];
    });
}

@end
