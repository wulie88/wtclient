//  
//  TransferStatusController.m
//
//  $URL$
//
//  $Revision$
//  $LastChangedDate$
//  $LastChangedBy$
//
//  This part of source code is distributed under MIT Licence
//  Copyright (c) 2009 Alex Chugunov
//  http://code.google.com/p/wtclient/
//

#import "TransferStatusController.h"


@implementation TransferStatusController

@synthesize target, closeAction, abortAction, active;

- (id)initWithTarget:(id)theTarget abortAction:(SEL)anAbortAction closeAction:(SEL)aCloseAction {
    if (self = [super init]) {
	target = theTarget;
	abortAction = anAbortAction;
	closeAction = aCloseAction;
    }
    return self;
}

- (void)showInView:(UIView *)aView {
    if (aView) {
	[aView addSubview:self.view];
	[aView bringSubviewToFront:self.view];
    }
}

- (void)dismiss {
    [self.view removeFromSuperview];
}

- (void)setActive:(BOOL)activity {
    active = activity;
    if (active) {
	[self.button removeTarget:self.target action:NULL forControlEvents:UIControlEventAllEvents];
	[self.button setTitle:@"Abort" forState:UIControlStateNormal];
	[self.button addTarget:self.target
	 action:self.abortAction
	 forControlEvents:UIControlEventTouchUpInside];
	[self.activityIndicator startAnimating];
    }
    else {
	[self.button removeTarget:self.target action:NULL forControlEvents:UIControlEventAllEvents];
	[self.button setTitle:@"OK" forState:UIControlStateNormal];
	[self.button addTarget:self.target
	 action:self.closeAction
	 forControlEvents:UIControlEventTouchUpInside];
	[self.activityIndicator stopAnimating];
    }
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    
    UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 220)];
    progressView.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height/2);
    
    [progressView addSubview:self.statusLabel];
    [progressView addSubview:self.activityIndicator];
    [progressView addSubview:self.progressLabel];
    [progressView addSubview:self.button];
    
    [self.view addSubview:progressView];
    [progressView release];
}
 
- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
    
- (UILabel *)progressLabel {
    if (progressLabel == nil) {
	progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 140, 200, 20)];
	progressLabel.textAlignment = UITextAlignmentCenter;
	progressLabel.font = [UIFont boldSystemFontOfSize:14.0];
	progressLabel.textColor = [UIColor lightGrayColor];
	progressLabel.backgroundColor = [UIColor clearColor];
	progressLabel.text = @"0% complete";
    }
    return progressLabel;
}

- (UILabel *)statusLabel {
    if (statusLabel == nil) {
	statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 200, 40)];
	statusLabel.textAlignment = UITextAlignmentCenter;
	statusLabel.font = [UIFont boldSystemFontOfSize:14.0];
	statusLabel.textColor = [UIColor lightGrayColor];
	statusLabel.backgroundColor = [UIColor clearColor];
	statusLabel.lineBreakMode = UILineBreakModeWordWrap;
	statusLabel.numberOfLines = 0;
	statusLabel.text = @"Uploading file";
    }
    return statusLabel;
}
    
- (UIActivityIndicatorView *)activityIndicator; {
    if (activityIndicator == nil) {
	activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
	activityIndicator.center = CGPointMake(100, 100);
	activityIndicator.hidesWhenStopped = NO;
    }
    return activityIndicator;
}

- (UIButton *)button {
    if (button == nil) {
	button = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
	button.frame = CGRectMake(40, 180, 120, 40);	
    }
    return button;
}

- (NSString *)statusMessage {
    return self.statusLabel.text;
}

- (void)setStatusMessage:(NSString *)aMessage {
    self.statusLabel.text = aMessage;
}

- (NSString *)progressMessage {
    return self.progressLabel.text;
}

- (void)setProgressMessage:(NSString *)aMessage {
    self.progressLabel.text = aMessage;
}

- (void)dealloc {
    [button release];
    [statusLabel release];
    [progressLabel release];
    [activityIndicator release];
    [super dealloc];
}


@end
