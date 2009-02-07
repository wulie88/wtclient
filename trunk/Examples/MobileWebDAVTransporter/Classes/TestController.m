//  
//  TestController.m
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


#import "TestController.h"
#import "TransferStatusController.h"
#import <netinet/in.h>

@implementation TestController
@synthesize uploadButton, downloadButton;
@synthesize remoteURLTextField, localFilenameTextField, remoteURLLabel, localFilenameLabel;
@synthesize transferClient,  transferStatusController;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.localFilenameTextField.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"localFilename"];
    self.localFilenameTextField.placeholder = @"test.dat";
    self.remoteURLTextField.text = [[NSUserDefaults standardUserDefaults] valueForKey:@"remoteURL"];
    self.remoteURLTextField.placeholder = @"https://idisk.mac.com/user/test.dat";
}

- (IBAction)uploadFile:(id)sender {
    transferType = TransferTypeUpload;
    NSLog(@"Upload file at path: %@", self.filePath);
    NSLog(@"Remote URL: %@", self.remoteURL);
    if (self.filePath && [[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
	[self prepareTransferClient];
    }
    else {
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"File not found"
							    message:nil
							   delegate:nil
						  cancelButtonTitle:@"OK"
						  otherButtonTitles:nil];
	[alertView show];
	[alertView release];
    }
}

- (IBAction)downloadFile:(id)sender {
    transferType = TransferTypeDownload;
    NSLog(@"Download into file at path: %@", self.filePath);
    NSLog(@"Remote URL: %@", self.remoteURL);
    [self prepareTransferClient];
}

- (void)prepareTransferClient {
    if ([self networkIsReachable]) {
	connectionEstablished = NO;
	estimatedLength = 0;
	[self.transferStatusController setActive:YES];
	[self.transferStatusController setStatusMessage:@"Preparing request"];
	[self.transferStatusController setProgressMessage:@""];
	[self.transferStatusController showInView:self.view.window];
	self.transferClient = [[[WTClient alloc] initWithLocalURL:[NSURL fileURLWithPath:self.filePath]
								remoteURL:self.remoteURL 
								 username:self.username
								 password:self.password] autorelease];
	
	[self.transferClient setDelegate:self];
	[self performSelectorInBackground:@selector(startTransfer) withObject:nil];
    }
    else {
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Network is unreachable"
						       message:nil
						      delegate:nil
					     cancelButtonTitle:@"OK"
					     otherButtonTitles:nil];
	[alertView show];
	[alertView release];
    }
}

- (void)startTransfer {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [self.transferClient requestProperties];
    [pool release];
}

- (BOOL)networkIsReachable {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityFlags flags;
    BOOL gotFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
    CFRelease(defaultRouteReachability);
    if (!gotFlags) {
        return NO;
    }
    BOOL isReachable = flags & kSCNetworkReachabilityFlagsReachable;
    
    BOOL noConnectionRequired = !(flags & kSCNetworkReachabilityFlagsConnectionRequired);
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN)) {
	noConnectionRequired = YES;
    }
    
    return (isReachable && noConnectionRequired) ? YES : NO;
}

- (void)transferClientDidBeginConnecting:(WTClient *)client {
    NSLog(@"Establishing connection");
    if (!connectionEstablished) {
	[self.transferStatusController setStatusMessage:@"Establishing connection"];
    }
}

- (void)transferClientDidEstablishConnection:(WTClient *)client {
    NSLog(@"Connection established");
}

- (void)transferClientDidFailToEstablishConnection:(WTClient *)client {
    [self.transferStatusController setActive:NO];
    [self.transferStatusController setStatusMessage:@"Cannot establish connection"];
}

- (void)transferClientDidCloseConnection:(WTClient *)client {
    [self.transferStatusController setActive:NO];
    [self.transferStatusController setStatusMessage:@"Connection closed"];
}

- (void)transferClientDidLoseConnection:(WTClient *)client {
    [self.transferStatusController setActive:NO];
    [self.transferStatusController setStatusMessage:@"Connection lost"];
}

- (void)transferClientDidFailToPassAuthenticationChallenge:(WTClient *)client {
    [self.transferStatusController setActive:NO];
    [self.transferStatusController setStatusMessage:@"Authentication falied"];
}

- (void)transferClientDidReceivePropertiesResponse:(WTClient *)client {
    [self.transferStatusController setStatusMessage:@"Authentication passed"];
    NSUInteger statusCode = [[client.currentResponse valueForKey:@"statusCode"] intValue];
    NSLog(@"Response to properties request: %u", statusCode);
    if (statusCode == 404) {
	if (transferType == TransferTypeDownload) {
	    [self.transferStatusController setActive:NO];
	    [self.transferStatusController setStatusMessage:@"Requested file not found on server"];
	    return;
	}
    }
    else if (statusCode == 207) {
	if (transferType == TransferTypeDownload) {
	    if ([[[client properties] valueForKey:@"status"] isEqualToString:@"HTTP/1.1 200 OK"]) {
		estimatedLength = (unsigned)[[[client properties] valueForKey:@"getcontentlength"] longLongValue];
		[transferClient downloadFile];
		return;
	    }
	    else {
		[self.transferStatusController setActive:NO];
		[self.transferStatusController setStatusMessage:@"Requested file cannot be accessed"];
		return;
	    }
	}
    }
    else {
	[self.transferStatusController setActive:NO];
	[self.transferStatusController setStatusMessage:@"Error. Unexpected response from server"];
	return;
    }

    if (transferType == TransferTypeUpload) {
	estimatedLength = [[[[NSFileManager defaultManager] attributesOfItemAtPath:self.filePath error:nil] valueForKey:NSFileSize] unsignedLongLongValue];
	[transferClient uploadFile];
    }
}

- (void)transferClientDidBeginTransfer:(WTClient *)client {
    NSLog(@"Begin transfer");
    if (transferType == TransferTypeUpload) {
	[self.transferStatusController setStatusMessage:@"Uploading data"];
    }
    else {
	[self.transferStatusController setStatusMessage:@"Downloading data"];
    }
}

- (void)transferClientDidFinishTransfer:(WTClient *)client {
    [self.transferStatusController setActive:NO];
    NSUInteger status = [[client.currentResponse valueForKey:@"statusCode"] unsignedIntValue];
    if (status >= 200 && status < 300) {
	[self.transferStatusController setStatusMessage:@"Transfer complete"];
    }
    else {
	[self.transferStatusController setStatusMessage:@"Transfer failed"];
    }
}

- (void)transferClient:(WTClient *)client didSendBytes:(unsigned long long)bytesWritten {
    [self.transferStatusController setProgressMessage:[NSString stringWithFormat:@"%quKb of %quKb sent", bytesWritten/1024, estimatedLength/1024]];
}

- (void)transferClient:(WTClient *)client didReceiveBytes:(unsigned long long)bytesReceived {
    [self.transferStatusController setProgressMessage:[NSString stringWithFormat:@"%quKb of %quKb received", bytesReceived/1024, estimatedLength/1024]];
}

- (NSString *)filePath {
    NSString *filename = [[NSUserDefaults standardUserDefaults] valueForKey:@"localFilename"];
    if (transferType == TransferTypeUpload) {
	return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
    }
    else {
	return [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:filename];
    }
}

- (NSURL *)remoteURL {
    return [NSURL URLWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"remoteURL"]];
}

- (NSString *)username {
    return [[NSUserDefaults standardUserDefaults] valueForKey:@"username"];
}

- (NSString *)password {
    return [[NSUserDefaults standardUserDefaults] valueForKey:@"password"];
}

- (TransferStatusController *)transferStatusController {
    if (transferStatusController == nil) {
	transferStatusController = [[TransferStatusController alloc] initWithTarget:self
									abortAction:@selector(abortTransfer:)
									closeAction:@selector(dismissTransferProgress:)];
    }
    return transferStatusController;
}

- (void)dismissTransferProgress:(id)sender {
    [self.transferStatusController dismiss];
    self.transferClient = nil;
}

- (void)abortTransfer:(id)sender {
    [self.transferClient stopTransfer];
    [self.transferStatusController dismiss];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.remoteURLTextField) {
	[[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:@"remoteURL"];
    }
    else if (textField == self.localFilenameTextField) {
	[[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:@"localFilename"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    [textField resignFirstResponder];
    return YES;
}

- (void)dealloc {
    [transferClient stopTransfer];
    [transferStatusController release];
    [transferClient release];
    
    [localFilenameLabel release];
    [remoteURLLabel release];
    [localFilenameTextField release];
    [remoteURLTextField release];
    
    [downloadButton release];
    [uploadButton release];
    
    [super dealloc];
}


@end
