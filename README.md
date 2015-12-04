# webpay-token-ios [![Travis](https://img.shields.io/travis/webpay/webpay-token-ios.svg?style=flat)](https://travis-ci.org/webpay/webpay-token-ios) [![CocoaPods](https://img.shields.io/cocoapods/v/WebPay.svg?style=flat)](http://cocoapods.org/?q=name%3AWEBPAY) [![CocoaPods](https://img.shields.io/cocoapods/p/WebPay.svg?style=flat)](https://github.com/webpay/webpay-token-ios#) [![CocoaPods](https://img.shields.io/cocoapods/l/WebPay.svg?style=flat)](https://github.com/webpay/webpay-token-ios/blob/master/LICENSE)

webpay-token-ios is an iOS library for creating a WebPay token from a credit card.

<img src="https://raw.github.com/webpay/webpay-token-ios/screenshot/screenshots/filled_card_form.png" width="300px;" />


## Sample App Using Card.io
There is a [sample app](https://github.com/webpay/webpay-token-ios-sample-card.io) using [card.io](https://www.card.io/)


## Requirements
webpay-token-ios supports iOS 7 and above.


## Installation

You can either install using cocoapods(recommended) or copying files manually.

### 1. Cocoapods(Recommended)
In your Podfile, add a line
```
pod 'WebPay', '~> 2.0.3'
```
then, run `pod install`.


### 2. Copy files manually

1. Clone this repository
2. Add files under Webpay directory to your project


### For objective-c projects
Add `#import "Webpay.h"` in one of your files, and see if your target builds without error.


### For swift projects
You need to create a bridging header and add `#import "Webpay.h"` to the header to use the library in swift code.
For instruction on how to create a bridging header, please refer to [Apple's documentation](https://developer.apple.com/library/ios/documentation/swift/conceptual/buildingcocoaapps/MixandMatch.html).


## Overview

webpay-token-ios consists of 3 components.

1. WPYPaymentViewController(view controller)
2. WPYTokenizer(model that creates a token)
3. WPYCardFormView(card form view)

If you want a view controller to drop in, WPYPaymentViewController is the way to go.
WPYTokenizer is for developers planning to create their own view & view controller from scratch. It provides API for accessing
WebPay API. WPYCardFormView offers a form with validation.

## How to use

### Initialization
Initialization is required for using any components from this library.

```objective-c
// objective-c

#import "Webpay.h"

// replace test_public_YOUR_PUBLIC_KEY with your WebPay publishable key
[WPYTokenizer setPublicKey:@"test_public_YOUR_PUBLIC_KEY"];
```

```swift
// swift

// replace test_public_YOUR_PUBLIC_KEY with your WebPay publishable key
WPYTokenizer.setPublicKey("test_public_YOUR_PUBLIC_KEY")
```

### WPYPaymentViewController
If you just want a viewcontroller for `pushViewController:animated` or `presentViewController:animated:completion:`, this is what you want.

<img src="https://raw.github.com/webpay/webpay-token-ios/screenshot/screenshots/card_form.png" width="300px;" />

```objective-c
// objective-c
// version 2.x
WPYPaymentViewController *paymentViewController = [WPYPaymentViewController paymentViewControllerWithPriceTag:@"¥350" callback:^(WPYPaymentViewController *viewController, WPYToken *token, NSError *error) {
  if (error)
  {
    NSLog(@"error:%@", [error localizedDescription]);
  }
  else
  {
    //post token to your server

    // when transaction is complete
    [viewController setPayButtonComplete]; // this will change the button color to green and its title to checkmark
    [viewController dismissAfterDelay: 2.0f];
  }
}];

[self.navigationController pushViewController:paymentViewController animated:YES];

// version 1.x
WPYPaymentViewController *paymentViewController = [[WPYPaymentViewController alloc] initWithPriceTag:@"¥350" callback:^(WPYPaymentViewController *viewController, WPYToken *token, NSError *error) {
  if (error)
  {
    NSLog(@"error:%@", [error localizedDescription]);
  }
  else
  {
    //post token to your server

    // when transaction is complete
    [viewController setPayButtonComplete]; // this will change the button color to green and its title to checkmark
    [viewController dismissAfterDelay: 2.0f];
  }
}];

[self.navigationController pushViewController:paymentViewController animated:YES];
```

```swift
// swift

let paymentViewController = WPYPaymentViewController(priceTag: "¥350", callback: { viewController, token, error in
  if let newError = error {
    println("error:\(error.localizedDescription)")
  } else {
    //post token to your server

    // when transaction is complete
    viewController.setPayButtonComplete()
    viewController.dismissAfterDelay(2.0)
  }
})

self.navigationController?.pushViewController(paymentViewController, animated: true)
```

If you want the card form to be populated with card data, use `initWithPriceTag:card:callback:` instead.


### WPYTokenizer (Model)
If you are creating your own view, create token using WPYTokenizer.

```objective-c
// objective-c

#import "Webpay.h"

// create a credit card model and populate with data
WPYCreditCard *card = [[WPYCreditCard alloc] init];
card.number = @"4242424242424242";
card.expiryYear = 2015;
card.expiryMonth = 12;
card.cvc = @"123";
card.name = @"TARO YAMADA";

// pass card instance and a callback
[WPYTokenizer createTokenFromCard:card
                  completionBlock:^(WPYToken *token, NSError *error) {
  if (error)
  {
    NSLog(@"error:%@", [error localizedDescription]);
  }
  else
  {
    NSLog(@"token:%@", token.tokenId);
  }
}];
```

```swift
// swift

// create a credit card model and populate with data
let card = WPYCreditCard()
card.number = "4242424242424242"
card.expiryYear = 2015
card.expiryMonth = WPYMonth.December
card.cvc = "123"
card.name = "TARO YAMADA"

// pass card instance and a callback
WPYTokenizer.createTokenFromCard(card, completionBlock: {token, error in
  if let newError = error {
    println("\(error)")
  } else {
    println("\(token.tokenId)")
  }
})
```

### WPYCardFormView (View)
WPYCardFormView is a credit card form view that calls its delegate method when the form is valid. It handles padding credit card number, masking security code, and validating each field.

```objective-c
// objective-c

// create view
WPYCreditCard *card = [[WPYCreditCard alloc] init];
WPYCardFormView *cardForm = [[WPYCardFormView alloc] initWithFrame:CGRectMake(0, 0, 320, 300) card:card];
cardForm.delegate = self;
[self.view addSubview: cardForm];

// WPYCardFormDelegate methods
- (void)validFormWithCard:(WPYCreditCard *)creditCard
{
  // called when the form is valid.
}
```

```swift
// swift

// create view
let card = WPYCreditCard()
let form = WPYCardFormView(frame: CGRect(x: 0, y: 0, width: 320, height: 320), card: card)
form.delegate = self
self.view.addSubview(form)

// WPYCardFormDelegate methods
func validFormWithCard(creditCard: WPYCreditCard!) {
  // called when the form is valid.
}
```

If you want more granular control, use subclasses of `WPYAbstractCardField`.


### Other classes
#### WPYCreditCard
WPYCreditCard offers various validation methods.
For validating the whole card, use `- (BOOL)validate:`
```objective-c
// objective-c

NSError *cardError = nil;
if (![card validate:&cardError])
{
  NSLog(@"error:%@", [cardError localizedDescription]);
}
```

```swift
// swift

var cardError: NSError?
if !card.validate(&cardError) {
  println("error:\(cardError.localizedDescription)")
}
```

For validating each property, use `- (BOOL)validatePROPERTY:error:`
```objective-c
// objective-c

NSString *number = @"4242424242424242";
NSError *cardError = nil;
WPYCreditCard *card = [[WPYCreditCard alloc] init];
if (![card validateNumber:&number error:&cardError])
{
  NSLog(@"error:%@", [cardError localizedDescription]);
}
```

```swift
// swift

var number: AnyObject? = "4242424242424242"
var cardError: NSError?
let card = WPYCreditCard()
if !card.validateNumber(&number, error:&cardError) {
  println("error:\(cardError.localizedDescription)")
}
```

For checking brand from partial numbers
```objective-c
// objective-c

[WPYCreditCard brandNameFromPartialNumber:@"42"];
```

```swift
// swift

WPYCreditCard.brandNameFromPartialNumber("42")
```

#### WPYToken
WPYToken holds token data returned from Webpay API.

#### WPYError
This class defines all the errors originating from webpay-ios-token.

