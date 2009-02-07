//  
//  TestController.h
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

#import <UIKit/UIKit.h>
#import <CFNetwork/CFNetwork.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "WTClient.h"

@class TransferStatusController;

typedef enum {
    TransferTypeDownload,
    TransferTypeUpload
} TransferType;

@interface TestController : UIViewController <WTClientDelegate, UITextFieldDelegate> {
    BOOL connectionEstablished;
    unsigned long long estimatedLength;
    TransferType transferType;
    
    UIButton *uploadButton;
    UIButton *downloadButton;
    
    UITextField *remoteURLTextField;
    UITextField *localFilenameTextField;
    UILabel *localFilenameLabel;
    UILabel *remoteURLLabel;
        
    WTClient *transferClient;
    TransferStatusController *transferStatusController;
}

- (void)startTransfer;
- (void)prepareTransferClient;
- (IBAction)uploadFile:(id)sender;
- (IBAction)downloadFile:(id)sender;
- (BOOL)networkIsReachable;

- (void)dismissTransferProgress:(id)sender;
- (void)abortTransfer:(id)sender;

@property (nonatomic, readonly) IBOutlet UIButton *uploadButton;
@property (nonatomic, readonly) IBOutlet UIButton *downloadButton;
@property (nonatomic, readonly) IBOutlet UITextField *remoteURLTextField;
@property (nonatomic, readonly) IBOutlet UITextField *localFilenameTextField;
@property (nonatomic, readonly) IBOutlet UILabel *localFilenameLabel;
@property (nonatomic, readonly) IBOutlet UILabel *remoteURLLabel;
@property (nonatomic, retain) WTClient *transferClient;
@property (nonatomic, readonly) NSString *filePath;
@property (nonatomic, readonly) NSURL *remoteURL;
@property (nonatomic, readonly) NSString *username;
@property (nonatomic, readonly) NSString *password;
@property (nonatomic, readonly) TransferStatusController *transferStatusController;

@end
