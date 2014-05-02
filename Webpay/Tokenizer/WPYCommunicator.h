//
//  WPYHTTPRequestSerializer.h
//  Webpay
//
//  Created by yohei on 4/3/14.
//  Copyright (c) 2014 yohei, YasuLab. All rights reserved.
//

// During a request, he connection maintains a strong reference to its delegate.
#import <Foundation/Foundation.h>

@class WPYCreditCard;

typedef void (^WPYCommunicatorCompBlock)(NSURLResponse *, NSData *, NSError *);

@interface WPYCommunicator : NSObject
- (void)requestTokenWithPublicKey:(NSString *)publicKey
                             card:(WPYCreditCard *)card
                  completionBlock:(WPYCommunicatorCompBlock)compBlock;

@end
