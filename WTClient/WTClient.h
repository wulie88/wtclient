//
//  WTClient.h
//
//  $Revision$
//  $LastChangedDate$
//  $LastChangedBy$
//
//  This part of source code is distributed under MIT Licence
//  Copyright (c) 2009 Alex Chugunov
//  http://code.google.com/p/wtclient/
//

#import <Foundation/Foundation.h>
#import "WTHTTPConnection.h"

@protocol WTClientDelegate;

@interface WTClient : NSObject <WTHTTPConnectionDelegate> {
    BOOL authorized;
    
    NSURL *remoteURL;
    NSURL *localURL;
    NSDictionary *credentials;
    NSDictionary *currentResponse;
    
    NSMutableDictionary *properties;
    NSMutableString *currentPropertyValue;
    
    WTHTTPConnection *propertiesConnection;
    WTHTTPConnection *uploadConnection;
    WTHTTPConnection *downloadConnection;
    
    CFHTTPAuthenticationRef authentication;
    
    id<WTClientDelegate> delegate;
}

@property (nonatomic, retain) NSURL *remoteURL;
@property (nonatomic, retain) NSURL *localURL;
@property (nonatomic, retain) NSMutableDictionary *properties;
@property (nonatomic, retain) NSMutableString *currentPropertyValue;
@property (nonatomic, retain) WTHTTPConnection *propertiesConnection;
@property (nonatomic, retain) WTHTTPConnection *uploadConnection;
@property (nonatomic, retain) WTHTTPConnection *downloadConnection;
@property (nonatomic, assign) id<WTClientDelegate> delegate;
@property (nonatomic, retain) NSDictionary *currentResponse;
@property (nonatomic, retain) NSDictionary *credentials;
@property (nonatomic) CFHTTPAuthenticationRef authentication;

- (id)initWithLocalURL:(NSURL *)aLocalURL remoteURL:(NSURL *)aRemoteURL username:(NSString *)username password:(NSString *)password;
- (BOOL)preparePropertiesConnection;
- (void)requestProperties;
- (void)stopTransfer;
- (void)uploadFile;
- (void)downloadFile;

@end

@protocol WTClientDelegate <NSObject>

@optional
- (void)transferClientDidBeginConnecting:(WTClient *)client;
- (void)transferClientDidEstablishConnection:(WTClient *)client;
- (void)transferClientDidFailToEstablishConnection:(WTClient *)client;
- (void)transferClientDidCloseConnection:(WTClient *)client;
- (void)transferClientDidLoseConnection:(WTClient *)client;
- (void)transferClientDidFailToPassAuthenticationChallenge:(WTClient *)client;
- (void)transferClientDidReceivePropertiesResponse:(WTClient *)client;

- (void)transferClientDidBeginTransfer:(WTClient *)client;
- (void)transferClientDidFinishTransfer:(WTClient *)client;
- (void)transferClient:(WTClient *)client didSendBytes:(unsigned long long)bytesWritten;
- (void)transferClient:(WTClient *)client didReceiveBytes:(unsigned long long)bytesWritten;

@end
