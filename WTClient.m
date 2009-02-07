//
//  WTClient.m
//
//  $Revision$
//  $LastChangedDate$
//  $LastChangedBy$
//
//  This part of source code is distributed under MIT Licence
//  Copyright (c) 2009 Alex Chugunov
//  http://code.google.com/p/wtclient/
//


#import "WTClient.h"

@implementation WTClient
@synthesize remoteURL, credentials, properties, currentResponse, currentPropertyValue, delegate, propertiesConnection, authentication;
@synthesize downloadConnection, uploadConnection, localURL;

- (id)initWithLocalURL:(NSURL *)aLocalURL remoteURL:(NSURL *)aRemoteURL username:(NSString *)username password:(NSString *)password {
    if (self = [super init]) {
	remoteURL = [aRemoteURL retain];
	localURL = [aLocalURL retain];
	credentials = [[NSDictionary alloc] initWithObjectsAndKeys:
		       username, kCFHTTPAuthenticationUsername,
		       password, kCFHTTPAuthenticationPassword,
		       nil];
    }
    return self;
}

- (BOOL)preparePropertiesConnection {
    WTHTTPConnection *connection = [[WTHTTPConnection alloc] initWithDestination:remoteURL
									protocol:@"PROPFIND"];
    self.propertiesConnection = connection;
    [connection release];
    if (!self.propertiesConnection) {
	if ([self.delegate respondsToSelector:@selector(transferClientDidFailToEstablishConnection:)]) {
	    [self.delegate transferClientDidFailToEstablishConnection:self];
	}
	return NO;
    }
    
    //TODO: request all properties here
    [self.propertiesConnection setRequestBodyWithData:[[NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"utf-8\" ?><D:propfind xmlns:D=\"DAV:\"><D:prop><D:getcontentlength/></D:prop></D:propfind>", remoteURL] dataUsingEncoding:NSUTF8StringEncoding]];
    [self.propertiesConnection setDelegate:self];
    return YES;
}

- (void)requestProperties {
    if ([self preparePropertiesConnection]) {
	self.properties = [NSMutableDictionary dictionary];
	[self.propertiesConnection openStream];
    }
}

- (void)uploadFile {
    if (self.uploadConnection == nil) {
	WTHTTPConnection *connection = [[WTHTTPConnection alloc] initWithDestination:remoteURL
									    protocol:@"PUT"];
	self.uploadConnection = connection;
	[connection release];
    }
    if (!self.uploadConnection) {
	if ([self.delegate respondsToSelector:@selector(transferClientDidFailToEstablishConnection:)]) {
	    [self.delegate transferClientDidFailToEstablishConnection:self];
	}
	return;
    }
    
    if (self.authentication) {
	if (![self.uploadConnection setAuthentication:self.authentication credentials:self.credentials]) {
	    if ([self.delegate respondsToSelector:@selector(transferClientDidFailToEstablishConnection:)]) {
		[self.delegate transferClientDidFailToEstablishConnection:self];
	    }
	    return;
	}
    }
    
    if (![self.uploadConnection setRequestBodyWithTargetURL:self.localURL offset:0]) {
	if ([self.delegate respondsToSelector:@selector(transferClientDidFailToEstablishConnection:)]) {
	    [self.delegate transferClientDidFailToEstablishConnection:self];
	}
	return;
    }
    
    [self.uploadConnection setDelegate:self];
    [self.uploadConnection openStream];
    
}

- (void)downloadFile {
    if (self.downloadConnection == nil) {
	WTHTTPConnection *connection = [[WTHTTPConnection alloc] initWithDestination:remoteURL
									    protocol:@"GET"];
	self.downloadConnection = connection;
	[connection release];
    }
    if (!self.downloadConnection) {
	if ([self.delegate respondsToSelector:@selector(transferClientDidFailToEstablishConnection:)]) {
	    [self.delegate transferClientDidFailToEstablishConnection:self];
	}
	return;
    }
    
    if (self.authentication) {
	if (![self.downloadConnection setAuthentication:self.authentication credentials:self.credentials]) {
	    if ([self.delegate respondsToSelector:@selector(transferClientDidFailToEstablishConnection:)]) {
		[self.delegate transferClientDidFailToEstablishConnection:self];
	    }
	    return;
	}
    }
    
    [self.downloadConnection setDelegate:self];
    [self.downloadConnection setLocalURL:self.localURL]; //to enable downloading into file instead of keeping data in memory
    [self.downloadConnection openStream];
}
    
- (void)stopTransfer {
    //try to close all connections and release them
    if (self.propertiesConnection) {
	[self.propertiesConnection closeStream];
	self.propertiesConnection = nil;
    }
    if (self.uploadConnection) {
	[self.uploadConnection closeStream];
	self.uploadConnection = nil;
    }
    if (self.downloadConnection) {
	[self.downloadConnection closeStream];
	self.downloadConnection = nil;
    }
    if ([self.delegate respondsToSelector:@selector(transferClientDidCloseConnection:)]) {
	[self.delegate transferClientDidCloseConnection:self];
    }
}

- (void)HTTPConnection:(WTHTTPConnection *)connection didSendBytes:(unsigned long long)amountOfBytes {
    if (connection == self.uploadConnection) {
	//If we are uploading a file then report about uploading progress to delegate
	if (self.delegate && [self.delegate respondsToSelector:@selector(transferClient:didSendBytes:)]) {
	    [self.delegate transferClient:self didSendBytes:amountOfBytes];
	}
    }
}

- (void)HTTPConnection:(WTHTTPConnection *)connection didReceiveBytes:(unsigned long long)amountOfBytes {
    if (connection == self.downloadConnection) {
	//If we are downloading a file then report about downloading progress to delegate
	if (self.delegate && [self.delegate respondsToSelector:@selector(transferClient:didReceiveBytes:)]) {
	    [self.delegate transferClient:self didReceiveBytes:amountOfBytes];
	}
    }
}

- (void)HTTPConnection:(WTHTTPConnection *)connection didReceiveResponse:(NSDictionary *)response {
    self.currentResponse = response;
    if (connection == self.propertiesConnection) {
	//get properties from response body and report about to delegate when finished
	NSXMLParser *xmlParser = [[[NSXMLParser alloc] initWithData:[response valueForKey:@"responseBody"]] autorelease];
	[xmlParser setDelegate:self];
	[xmlParser parse];
    }
    else if (connection == self.uploadConnection || connection == self.downloadConnection) {
	if ([self.delegate respondsToSelector:@selector(transferClientDidFinishTransfer:)]) {
	    [self.delegate transferClientDidFinishTransfer:self];
	}	
    }
}

- (void)HTTPConnection:(WTHTTPConnection *)connection didReceiveAuthenticationChallenge:(CFHTTPAuthenticationRef)authenticationRef {
    self.authentication = authenticationRef;
    if (![connection setAuthentication:self.authentication credentials:credentials]) {
	NSLog(@"Cannot provide authentication credentials for connection");
	if ([self.delegate respondsToSelector:@selector(transferClientDidFailToEstablishConnection:)]) {
	    [self.delegate transferClientDidFailToEstablishConnection:self];
	}
	return;
    }	
    
    if (![connection openStream]) {
	if ([self.delegate respondsToSelector:@selector(transferClientDidFailToEstablishConnection:)]) {
	    [self.delegate transferClientDidFailToEstablishConnection:self];
	}
    }
}

- (void)HTTPConnection:(WTHTTPConnection *)connection didFailToPassAuthenticationChallenge:(CFHTTPAuthenticationRef)authentication {
    if ([self.delegate respondsToSelector:@selector(transferClientDidFailToPassAuthenticationChallenge:)]) {
	[self.delegate transferClientDidFailToPassAuthenticationChallenge:self];
    }
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    //get rid of namespaces
    NSString *key = nil;
    NSArray *parts = [[elementName lowercaseString] componentsSeparatedByString:@":"];
    if ([parts count] > 1) {
	key = [parts lastObject];
    }
    else {
	key = [parts objectAtIndex:0];
    }
    
    if ([key isEqualToString:@"getcontentlength"] || [key isEqualToString:@"status"]) {
	[self.properties setObject:[NSMutableString string] forKey:key];
	self.currentPropertyValue = [self.properties objectForKey:key];
    }
    //TODO: here should be proper properties parser
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    self.currentPropertyValue = nil;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (self.currentPropertyValue) {
	[self.currentPropertyValue appendString:string];
    }
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    if ([self.delegate respondsToSelector:@selector(transferClientDidReceivePropertiesResponse:)]) {
	[self.delegate transferClientDidReceivePropertiesResponse:self];
    }
}

- (void)interruptedHTTPConnection:(WTHTTPConnection *)connection {
    if ([self.delegate respondsToSelector:@selector(transferClientDidLoseConnection:)]) {
	[self.delegate transferClientDidLoseConnection:self];
    }
}

- (void)HTTPConnectionDidBeginEstablishingConnection:(WTHTTPConnection *)connection {
    if ([self.delegate respondsToSelector:@selector(transferClientDidBeginConnecting:)]) {
	[self.delegate transferClientDidBeginConnecting:self];
    }
}    
    
- (void)HTTPConnectionDidEstablish:(WTHTTPConnection *)connection {
    if ([self.delegate respondsToSelector:@selector(transferClientDidEstablishConnection:)]) {
	[self.delegate transferClientDidEstablishConnection:self];
    }
    if (connection == self.downloadConnection || connection == self.uploadConnection) {
	if ([self.delegate respondsToSelector:@selector(transferClientDidBeginTransfer:)]) {
	    [self.delegate transferClientDidBeginTransfer:self];
	}
    }
}

- (void)HTTPConnectionDidFailToEstablish:(WTHTTPConnection *)connection {
    if ([self.delegate respondsToSelector:@selector(transferClientDidFailToEstablishConnection:)]) {
	[self.delegate transferClientDidFailToEstablishConnection:self];
    }    
}


- (void)dealloc {
    NSLog(@"WTClient object will be deallocated");
    if (authentication) {
	CFRelease(authentication);
	authentication = NULL;
    }
    [localURL release];
    [remoteURL release];
    [downloadConnection release];
    [uploadConnection release];
    [currentResponse release];
    [credentials release];
    [properties release];
    [currentPropertyValue release];
    [propertiesConnection release];
    [super dealloc];
}

@end
