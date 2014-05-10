//
//  WPYAbstractFieldModel.h
//  Webpay
//
//  Created by yohei on 5/5/14.
//  Copyright (c) 2014 yohei, YasuLab. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "WPYCreditCard.h"

@interface WPYAbstractFieldModel : NSObject
@property(nonatomic, strong) WPYCreditCard *card;

- (instancetype)initWithCard:(WPYCreditCard *)card;

// methods to be overriden
- (void)setCardValue:(NSString *)value;
- (NSString *)cardValue;

- (NSString *)initialValueForTextField;
- (BOOL)canInsertNewValue:(NSString *)newValue;

- (BOOL)shouldValidateOnFocusLost;
- (BOOL)validate:(NSError * __autoreleasing *)error;
@end