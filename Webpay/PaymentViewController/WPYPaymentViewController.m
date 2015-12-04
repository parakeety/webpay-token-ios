//
//  WPYPaymentViewController.m
//  Webpay
//
//  Created by yohei on 4/11/14.
//  Copyright (c) 2014 yohei, YasuLab. All rights reserved.
//

#import "WPYPaymentViewController.h"

#import "WPYTokenizer.h"
#import "WPYCreditCard.h"

#import "WPYSupportedBrandsView.h"

#import "WPYAbstractCardField.h"
#import "WPYNumberField.h"
#import "WPYExpiryField.h"
#import "WPYCvcField.h"
#import "WPYNameField.h"

#import "WPYCardFormCell.h"

#import "WPYBundleManager.h"
#import "WPYDeviceSettings.h"


@interface WPYPaymentViewController ()<UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, copy) NSString *priceTag;
@property(nonatomic, strong) WPYCreditCard *card;
@property(nonatomic, copy) NSArray *supportedBrands;
@property(nonatomic, copy) WPYPaymentViewCallback callback;

@property(nonatomic, weak) IBOutlet UITableView *tableView;

@property(nonatomic, weak) IBOutlet UILabel *totalLabel;
@property(nonatomic, weak) IBOutlet UILabel *priceLabel;
@property(nonatomic, weak) IBOutlet UILabel *acceptLabel;
@property(nonatomic, weak) IBOutlet WPYSupportedBrandsView *supportedBrandsView;

@property(nonatomic, weak) IBOutlet UIButton *payButton;
@property(nonatomic, weak) IBOutlet UIActivityIndicatorView *indicator;

@property(nonatomic) BOOL isKeyboardDisplayed;
@property(nonatomic, strong) NSArray *titles;
@property(nonatomic, strong) NSArray *contentViews;
@end


// internal constants
static float const WPYPriceViewHeight = 100.0f;
static float const WPYFieldLeftMargin = 105.0f;
static float const WPYFieldRightMargin = 10.0f;
static float const WPYFieldTopMargin = 4.0f;
static float const WPYKeyboardAnimationDuration = 0.3f;
static float const WPYIphone4SHeight = 480.0f;
static float const WPYSuggestionBarHeight = 36.0f;
static NSString *const WPYFont = @"Avenir-Roman";


static UIImage *imageFromColor(UIColor *color)
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}


@implementation WPYPaymentViewController

#pragma mark initializer
+ (WPYPaymentViewController *)paymentViewControllerWithPriceTag:(NSString *)priceTag
                                                       callback:(WPYPaymentViewCallback)callback
{
    return [[self class] paymentViewControllerWithPriceTag:priceTag
                                                      card:[[WPYCreditCard alloc] init]
                                           supportedBrands:nil
                                                  callback:callback];
}

+ (WPYPaymentViewController *)paymentViewControllerWithPriceTag:(NSString *)priceTag
                                                           card:(WPYCreditCard *)card
                                                       callback:(WPYPaymentViewCallback)callback
{
    return [[self class] paymentViewControllerWithPriceTag:priceTag
                                                      card:card
                                           supportedBrands:nil
                                                  callback:callback];
}

+ (WPYPaymentViewController *)paymentViewControllerWithPriceTag:(NSString *)priceTag
                                                supportedBrands:(NSArray *)brands
                                                       callback:(WPYPaymentViewCallback)callback
{
    return [[self class] paymentViewControllerWithPriceTag:priceTag
                                                      card:[[WPYCreditCard alloc] init]
                                           supportedBrands:brands
                                                  callback:callback];
}

+ (WPYPaymentViewController *)paymentViewControllerWithPriceTag:(NSString *)priceTag
                                                           card:(WPYCreditCard *)card
                                                supportedBrands:(NSArray *)brands
                                                       callback:(WPYPaymentViewCallback)callback
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"WebPay"
                                                         bundle:[NSBundle bundleForClass:[self class]]];
    WPYPaymentViewController *vc = (WPYPaymentViewController *)[storyboard instantiateInitialViewController];
    vc.priceTag = priceTag;
    vc.card = card;
    vc.supportedBrands = brands;
    vc.callback = callback;
    
    return vc;
}

// override designated initializer
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        _isKeyboardDisplayed = NO;
        
        NSBundle *bundle = [WPYBundleManager localizationBundle];
        _titles = @[NSLocalizedStringFromTableInBundle(@"Number", WPYLocalizedStringTable, bundle, nil),
                    NSLocalizedStringFromTableInBundle(@"Expiry", WPYLocalizedStringTable, bundle, nil),
                    NSLocalizedStringFromTableInBundle(@"CVC", WPYLocalizedStringTable, bundle, nil),
                    NSLocalizedStringFromTableInBundle(@"Name", WPYLocalizedStringTable, bundle, nil)
                    ];
    }
    return self;
}



#pragma mark memory management
- (void)dealloc
{
    [self unsubscribeFromCardChange];
    [self unsubscribeFromKeyboardNotification];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}



#pragma mark public methods: compeletion
- (void)setPayButtonComplete
{
    [self.payButton setTitle:@"" forState:UIControlStateNormal];
    [self.payButton setBackgroundImage:imageFromColor([UIColor colorWithRed:0.18 green:0.8 blue:0.44 alpha:1]) forState:UIControlStateNormal];
    [self.payButton setImage:[WPYBundleManager imageNamed:@"check_white"] forState:UIControlStateNormal];
}

- (void)dismissAfterDelay:(NSTimeInterval)delay
{
    [self performSelector:@selector(dismiss) withObject:nil afterDelay:delay];
}

- (void)dismiss
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)popAfterDelay:(NSTimeInterval)delay
{
    [self performSelector:@selector(pop) withObject:nil afterDelay:delay];
}

- (void)pop
{
    [self.navigationController popViewControllerAnimated:YES];
}



#pragma mark view lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self subscribeToKeyboardNotification];
    
    [self setupPayButton];
    [self setupPriceView];
    [self setupFields];
    
    // listen to tap outside of textfield to dismiss keyboard
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
}

- (void)setupPayButton
{
    [self.payButton setEnabled:NO];
    
    // normal
    [self.payButton setTitle:NSLocalizedStringFromTableInBundle(@"Confirm Payment", WPYLocalizedStringTable, [WPYBundleManager localizationBundle], nil) forState:UIControlStateNormal];
    [self.payButton setBackgroundImage:imageFromColor([UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:0.8]) forState:UIControlStateNormal];
    
    // tapped
    [self.payButton setTitle:@"" forState:UIControlStateSelected];
    [self.payButton setBackgroundImage:imageFromColor([UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:1]) forState:UIControlStateHighlighted];
    
    // event handler
    [self.payButton addTarget:self
               action:@selector(payButtonPushed:)
     forControlEvents:UIControlEventTouchUpInside];
}

- (void)setupPriceView
{
    self.totalLabel.text = NSLocalizedStringFromTableInBundle(@"TOTAL", WPYLocalizedStringTable, [WPYBundleManager localizationBundle], nil);
    self.priceLabel.text = self.priceTag;
    self.acceptLabel.text = NSLocalizedStringFromTableInBundle(@"We Accept", WPYLocalizedStringTable, [WPYBundleManager localizationBundle], nil);
    
    if (self.supportedBrands) // brand passed
    {
        [self.supportedBrandsView showBrands:self.supportedBrands];
    }
    else
    {
        [WPYTokenizer fetchSupportedCardBrandsWithCompletionBlock:^(NSArray *supportedCardBrands, NSError *error) {
            if (!error)
            {
                [self.supportedBrandsView showBrands:supportedCardBrands];
            }
        }];
    }
}

- (void)setupFields
{
    CGRect fieldFrame = CGRectMake(WPYFieldLeftMargin, WPYFieldTopMargin, [[UIScreen mainScreen] bounds].size.width - WPYFieldLeftMargin - WPYFieldRightMargin, 45.0f);
    
    WPYAbstractCardField *numberField = [[WPYNumberField alloc] initWithFrame:fieldFrame card:self.card];
    WPYAbstractCardField *expiryField = [[WPYExpiryField alloc] initWithFrame:fieldFrame card:self.card];
    WPYAbstractCardField *cvcField = [[WPYCvcField alloc] initWithFrame:fieldFrame card:self.card];
    WPYAbstractCardField *nameField = [[WPYNameField alloc] initWithFrame:fieldFrame card:self.card];
    self.contentViews = @[numberField, expiryField, cvcField, nameField];
    
    [self subscribeToCardChange];
}


#pragma mark tableview
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.titles.count;
}

- (WPYCardFormCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    WPYCardFormCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    [cell setTitle:self.titles[indexPath.row]];
    [cell addField:self.contentViews[indexPath.row]];
    
    return cell;
}



#pragma mark pay button
- (void)payButtonPushed:(id)sender
{
    NSError *error = nil;
    if (![self.card validate:&error])
    {
        [[[UIAlertView alloc] initWithTitle:@"Error"
                                    message:[error localizedDescription]
                                   delegate:nil
                          cancelButtonTitle:@"dismiss"
                          otherButtonTitles:nil, nil] show];
        return;
    }
    
    [self startIndicator];
    
    [WPYTokenizer createTokenFromCard:self.card completionBlock:^(WPYToken *token, NSError *error) {
        [self stopIndicator];
        self.callback(self, token, error);
    }];
}

- (void)startIndicator
{
    [self.payButton setSelected:YES];
    [self.indicator startAnimating];
}

- (void)stopIndicator
{
    [self.payButton setSelected:NO];
    [self.indicator stopAnimating];
}



#pragma mark keyboard
- (void)subscribeToKeyboardNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:self.view.window];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:self.view.window];
    
}

- (void)unsubscribeFromKeyboardNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    float height = [WPYDeviceSettings isiOS8] ? WPYPriceViewHeight - 8 : WPYPriceViewHeight;
    if (!self.isKeyboardDisplayed)
    {
        [UIView animateWithDuration:WPYKeyboardAnimationDuration animations:^() {
            [self.tableView setContentOffset:CGPointMake(0, height) animated:NO];
        }];
        self.tableView.scrollEnabled = NO;
    }
    else
    {
        // called when keyboard is flick keyboard and suggestion bar is about to be displayed
        // On iphone4S, flick keyboard will hide namefield with suggestion bar
        // Scroll when iphone4s && namefield focused && suggestion bar shown
        WPYAbstractCardField *nameField = self.contentViews[3];
        if (self.view.frame.size.height <= WPYIphone4SHeight && [nameField.textField isFirstResponder])
        {
            [self.tableView setContentOffset:CGPointMake(0, height + WPYSuggestionBarHeight) animated:YES];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(nameFieldDoneEditing)
                                                         name:UITextFieldTextDidEndEditingNotification
                                                       object:nameField.textField];
        }
    }
    
    self.isKeyboardDisplayed = YES;
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    if (self.isKeyboardDisplayed)
    {
        [UIView animateWithDuration:WPYKeyboardAnimationDuration animations:^() {
            [self.tableView setContentOffset:CGPointMake(0, 0) animated:NO];
        }];
        self.tableView.scrollEnabled = YES;
    }
    
    self.isKeyboardDisplayed = NO;
}

- (void)dismissKeyboard
{
    [self.contentViews enumerateObjectsUsingBlock:^(WPYAbstractCardField *field, NSUInteger idx, BOOL *stop) {
        [field setFocus:NO];
    }];
}

- (void)nameFieldDoneEditing
{
    float height = [WPYDeviceSettings isiOS8] ? WPYPriceViewHeight - 8 : WPYPriceViewHeight;
    
    // When keyboard is returned, keyboardWillHide will be called first, setting height to 0
    // Restore only if contentOffset is height + bar height
    if (self.tableView.contentOffset.y == (height + WPYSuggestionBarHeight))
    {
        [self.tableView setContentOffset:CGPointMake(0, height) animated:YES];
    }
    
    WPYAbstractCardField *nameField = self.contentViews[3];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UITextFieldTextDidEndEditingNotification
                                                  object:nameField.textField];
}


#pragma mark cardfield change
- (void)subscribeToCardChange
{
    [self.card addObserver:self
                forKeyPath:NSStringFromSelector(@selector(name))
                   options:NSKeyValueObservingOptionInitial
                   context:nil];
    
    [self.card addObserver:self
                forKeyPath:NSStringFromSelector(@selector(number))
                   options:NSKeyValueObservingOptionInitial
                   context:nil];
    
    [self.card addObserver:self
                forKeyPath:NSStringFromSelector(@selector(cvc))
                   options:NSKeyValueObservingOptionInitial
                   context:nil];
    
    [self.card addObserver:self
                forKeyPath:NSStringFromSelector(@selector(expiryMonth))
                   options:NSKeyValueObservingOptionInitial
                   context:nil];
    
    [self.card addObserver:self
                forKeyPath:NSStringFromSelector(@selector(expiryYear))
                   options:NSKeyValueObservingOptionInitial
                   context:nil];
}

- (void)unsubscribeFromCardChange
{
    [self.card removeObserver:self forKeyPath:NSStringFromSelector(@selector(name))];
    [self.card removeObserver:self forKeyPath:NSStringFromSelector(@selector(number))];
    [self.card removeObserver:self forKeyPath:NSStringFromSelector(@selector(cvc))];
    [self.card removeObserver:self forKeyPath:NSStringFromSelector(@selector(expiryMonth))];
    [self.card removeObserver:self forKeyPath:NSStringFromSelector(@selector(expiryYear))];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    [self validate];
}

- (void)validate
{
    NSError *error = nil;
    if ([self.card validate: &error])
    {
        [self validForm];
    }
    else
    {
        [self invalidFormWithError:error];
    }
}

- (void)validForm
{
    [self.payButton setEnabled:YES];
}

- (void)invalidFormWithError:(NSError *)error
{
    [self.payButton setEnabled:NO];
}

@end
