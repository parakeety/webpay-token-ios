//
//  WPYAbstractCardField.m
//  Webpay
//
//  Created by yohei on 4/17/14.
//  Copyright (c) 2014 yohei, YasuLab. All rights reserved.
//

#import "WPYAbstractCardFieldSubclass.h"

static float const WPYShakeWidth = 1.0f;
static float const WPYShakeDuration = 0.03f;
static NSInteger const WPYMaxShakes = 8;


@interface WPYAbstractCardField ()
@end


@implementation WPYAbstractCardField
@synthesize textField = _textField;

#pragma mark initialization
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}



#pragma mark public methods
- (void)setFocus:(BOOL)focus
{
    if (focus)
    {
        [self.textField becomeFirstResponder];
    }
    else
    {
        [self.textField resignFirstResponder];
    }
}



#pragma mark protected methods
- (void)setErrorColor
{
    self.textField.textColor = [UIColor redColor];
}

- (void)setNormalColor
{
    self.textField.textColor = [UIColor darkGrayColor];
}

- (void)notifyValidity
{
    [self setNormalColor];
    if (self.delegate && [self.delegate respondsToSelector:@selector(validValue:forKey:)])
    {
        [self.delegate validValue:self.textField.text forKey:[self key]];
    }
}

- (void)notifyError:(NSError *)error
{
    [self setErrorColor];
    if (self.delegate && [self.delegate respondsToSelector:@selector(invalidValue:forKey:error:)])
    {
        [self.delegate invalidValue:self.textField.text forKey:[self key] error:error];
    }
}



#pragma mark textfield delegate
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self setNormalColor];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (![self shouldValidateOnFocusLost])
    {
        return;
    }
    
    NSError *error = nil;
    if ([self validate:&error])
    {
        [self notifyValidity];
    }
    else
    {
        [self startErrorAnimation];
        [self notifyError:error];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)replacementString
{
    NSString *newValue = [textField.text stringByReplacingCharactersInRange:range withString:replacementString];
    NSUInteger place = range.location + 1;
    BOOL isCharacterDeleted = replacementString.length == 0;
    
    [self updateValue:newValue place:place charactedDeleted:isCharacterDeleted];
    
    BOOL canInsertNewValue = [self canInsertNewValue:newValue place:place charactedDeleted:isCharacterDeleted];
    
    return canInsertNewValue;
}

// called when value of textfield updated. called from textfield or manually
- (void)textFieldDidChange:(id)sender
{
    if ([self validate:nil])
    {
        [self notifyValidity];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}



#pragma mark expected to overriden in subclass
- (WPYFieldKey)key
{
    return 100;
}

- (BOOL)shouldValidateOnFocusLost
{
    return NO;
}

- (BOOL)validate:(NSError * __autoreleasing *)error
{
    return YES;
}

- (BOOL)canInsertNewValue:(NSString *)newValue place:(NSUInteger)place charactedDeleted:(BOOL)isCharacterDeleted
{
    return YES;
}

- (void)updateValue:(NSString *)newValue
              place:(NSUInteger)place
   charactedDeleted:(BOOL)isCharacterDeleted
{
    
}



#pragma mark error notification animation
- (void)startErrorAnimation
{
    [self shake:WPYMaxShakes
      direction:1
       duration:WPYShakeDuration
     shakeWidth:WPYShakeWidth
  currentShakes:0];
}

- (void)shake:(NSInteger)times
    direction:(NSInteger)direction
     duration:(float)duration
   shakeWidth:(float)width
currentShakes:(NSInteger)shaked
{
    [UIView animateWithDuration:duration
                     animations:^{
                         self.transform = CGAffineTransformMakeTranslation(width * direction, 0);
                     }
                     completion:^(BOOL finished){
                         if (shaked == times)
                         {
                             self.transform = CGAffineTransformIdentity;
                             return;
                         }
                         
                         [self shake:times
                           direction:direction * -1
                            duration:duration
                          shakeWidth:width
                       currentShakes:shaked + 1];
    }];
}

@end