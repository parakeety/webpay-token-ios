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

#import "WPYAbstractCardField.h"
#import "WPYNumberField.h"
#import "WPYExpiryField.h"
#import "WPYCvcField.h"
#import "WPYNameField.h"

#import "WPYCardFormCell.h"

#import "WPYConstants.h"


@interface WPYPaymentViewController ()<UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) WPYCreditCard *card;

@property(nonatomic, copy) NSString *priceTag;
@property(nonatomic, copy) WPYPaymentViewCallback callback;

@property(nonatomic) BOOL isKeyboardDisplayed;
@property(nonatomic, strong) NSArray *titles;
@property(nonatomic, strong) NSArray *contentViews;

@property(nonatomic, strong) UIButton *payButton;
@property(nonatomic, strong) UIActivityIndicatorView *indicator;
@end


// internal constants
static float const WPYNavBarHeight = 64.0f;

static float const WPYKeyboardScrollAnimatinDuration = 0.3f;

static float const WPYPriceViewHeight = 100.0f;

static float const WPYFieldRightMargin = 10.0f; // for leaving right margin to rightview
static float const WPYFieldLeftMargin = 100.0f;
static float const WPYFieldTopMargin = 4.0f;
static float const WPYFieldWidth = 320.0f - WPYFieldLeftMargin - WPYFieldRightMargin;
static float const WPYFieldHeight = 45.0f;

static float const WPYCellHeight = 50.0f;



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
- (instancetype)initWithPriceTag:(NSString *)priceTag
                            card:(WPYCreditCard *)card
                        callback:(WPYPaymentViewCallback)callback;
{
    if (self = [super initWithStyle:UITableViewStyleGrouped])
    {
        _priceTag = priceTag;
        _card = card;
        _callback = callback;
        
        _isKeyboardDisplayed = NO;
        
        _titles = @[NSLocalizedStringFromTable(@"Number", WPYLocalizedStringTable, nil),
                    NSLocalizedStringFromTable(@"Expiry", WPYLocalizedStringTable, nil),
                    NSLocalizedStringFromTable(@"CVC", WPYLocalizedStringTable, nil),
                    NSLocalizedStringFromTable(@"Name", WPYLocalizedStringTable, nil)
                    ];
        
        // contentViews
        // for pre ios7, area of tableviewcell is smaller
        float x = isiOS7() ? WPYFieldLeftMargin : WPYFieldLeftMargin - 10;
        float width = isiOS7() ? WPYFieldWidth : WPYFieldWidth - 10;
        CGRect fieldFrame = CGRectMake(x, WPYFieldTopMargin, width, WPYFieldHeight);
        
        WPYAbstractCardField *numberField = [[WPYNumberField alloc] initWithFrame:fieldFrame card:_card];
        WPYAbstractCardField *expiryField = [[WPYExpiryField alloc] initWithFrame:fieldFrame card:_card];
        WPYAbstractCardField *cvcField = [[WPYCvcField alloc] initWithFrame:fieldFrame card:_card];
        WPYAbstractCardField *nameField = [[WPYNameField alloc] initWithFrame:fieldFrame card:_card];
        
        _contentViews = @[numberField, expiryField, cvcField, nameField];
        
        [self subscribeToCardChange];
    }
    
    return self;
}

- (instancetype)initWithPriceTag:(NSString *)priceTag
                        callback:(WPYPaymentViewCallback)callback
{
    WPYCreditCard *card = [[WPYCreditCard alloc] init];
    return [self initWithPriceTag:priceTag card:card callback:callback];
}

// override designated initializer of super
- (id)initWithStyle:(UITableViewStyle)style
{
    WPYCreditCard *card = [[WPYCreditCard alloc] init];
    return [self initWithPriceTag:@" " card:card callback:nil];
}



#pragma mark memory management
- (void)dealloc
{
    [self unsubscribeToCardChange];
    [self unsubscribeToKeyboardNotification];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}



#pragma mark public methods: compeletion
- (void)setPayButtonComplete
{
    [self.payButton setTitle:@" " forState:UIControlStateNormal];
    [self.payButton setBackgroundImage:imageFromColor([UIColor colorWithRed:0.18 green:0.8 blue:0.44 alpha:1]) forState:UIControlStateNormal];
    [self.payButton setImage:[UIImage imageNamed:@"check_white"] forState:UIControlStateNormal];
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
    
    if (isiOS7())
    {
        self.navigationController.navigationBar.translucent = NO;
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.navigationController.navigationBar.barTintColor  = [UIColor colorWithRed:0.99 green:0.99 blue:0.99 alpha:1.0];
        self.tableView.backgroundColor = [UIColor whiteColor];
    }
    else
    {
        // default background of uitableview in ios6 is stripe.
        // change the background to white to match the color with ios7.
        UIView *backgroundView = [[UIView alloc] init];
        backgroundView.backgroundColor = [UIColor colorWithRed:0.99 green:0.99 blue:0.99 alpha:1.0];
        [self.tableView setBackgroundView:backgroundView];
    }
    
    // price view
    UIView *priceView = [self createPriceView];
    self.tableView.tableHeaderView = priceView;
    
    // pay button
    self.payButton = [self createPayButton];
    [self.payButton setEnabled:NO];
    
    self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [self.indicator setCenter:CGPointMake(160, 25)];
    [self.payButton addSubview:self.indicator];
    
    [self.view addSubview:self.payButton];
    
    
    // listen to tap outside of textfield to dismiss keyboard
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
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
    WPYCardFormCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[WPYCardFormCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:CellIdentifier
                                          contentView:self.contentViews[indexPath.row]
                                                title:self.titles[indexPath.row]];
                
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return WPYCellHeight;
}



#pragma mark price view
- (UIView *)createPriceView
{
    UIView *priceView = [[UIView alloc] initWithFrame: CGRectMake(0.0f, 0.0f, self.tableView.bounds.size.width, WPYPriceViewHeight)];
    
    UIColor *priceColor = [UIColor colorWithRed:0.31 green:0.75 blue:0.99 alpha:1.0f];
    
    UILabel *leftLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 30, 60, 44)];
    leftLabel.text = NSLocalizedStringFromTable(@"TOTAL", WPYLocalizedStringTable, nil);
    leftLabel.textColor = priceColor;
    leftLabel.font = [UIFont fontWithName:@"Avenir-Roman" size:14.0f];
    leftLabel.backgroundColor = [UIColor clearColor];
    [priceView addSubview:leftLabel];
    
    UILabel *priceLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 25, 200, 50)];
    priceLabel.text = self.priceTag;
    priceLabel.textColor = priceColor;
    priceLabel.font = [UIFont fontWithName:@"Avenir-Roman" size:53.0f];
    priceLabel.backgroundColor = [UIColor clearColor];
    priceLabel.adjustsFontSizeToFitWidth = YES;
    priceLabel.minimumScaleFactor = 0.5;
    priceLabel.textAlignment = NSTextAlignmentCenter;
    priceLabel.numberOfLines = 0; // vertical align
    [priceView addSubview:priceLabel];
    
    return priceView;
}



#pragma mark pay button
- (UIButton *)createPayButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    
    float buttonHeight = 50.0f;
    float y = [[UIScreen mainScreen] bounds].size.height - WPYNavBarHeight - buttonHeight;
    button.frame = CGRectMake(0, y, 320, buttonHeight);
    
    button.titleLabel.font = [UIFont fontWithName:@"Avenir-Roman" size:20.0f];
    
    // normal
    [button setTitle:NSLocalizedStringFromTable(@"Confirm Payment", WPYLocalizedStringTable, nil) forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setBackgroundImage:imageFromColor([UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:0.8]) forState:UIControlStateNormal];
    
    // highlighted
    [button setTitle:@" " forState:UIControlStateSelected];
    [button setBackgroundImage:imageFromColor([UIColor colorWithRed:0 green:0.478 blue:1.0 alpha:1]) forState:UIControlStateHighlighted];
    
    [button addTarget:self
               action:@selector(payButtonPushed:)
     forControlEvents:UIControlEventTouchUpInside];
    
    return button;
}

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
    
    [WPYTokenizer createTokenFromCard:self.card completionBlock:^(WPYToken *token, NSError *error){
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

- (void)unsubscribeToKeyboardNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    if (!self.isKeyboardDisplayed)
    {
        // there is a top margin for tableview in pre ios7
        float height = isiOS7() ? -WPYPriceViewHeight : -WPYPriceViewHeight - 10;
        [UIView animateWithDuration:WPYKeyboardScrollAnimatinDuration animations:^{
            self.view.frame = CGRectOffset(self.view.frame, 0, height);
        }];
    }
    
    self.isKeyboardDisplayed = YES;
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    if (self.isKeyboardDisplayed)
    {
        float height = isiOS7() ? WPYPriceViewHeight : WPYPriceViewHeight + 10;
        [UIView animateWithDuration:WPYKeyboardScrollAnimatinDuration animations:^{
            self.view.frame = CGRectOffset(self.view.frame, 0, height);
        }];
    }
    
    self.isKeyboardDisplayed = NO;
}

- (void)dismissKeyboard
{
    [self.contentViews enumerateObjectsUsingBlock:^(WPYAbstractCardField *field, NSUInteger idx, BOOL *stop){
        [field setFocus:NO];
    }];
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

- (void)unsubscribeToCardChange
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
