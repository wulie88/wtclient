//
//  WTHTTPConnection.m
//
//  $Revision$
//  $LastChangedDate$
//  $LastChangedBy$
//
//  This part of source code is distributed under MIT Licence
//  Copyright (c) 2009 Alex Chugunov
//  http://code.google.com/p/wtclient/
//

#import "WTHTTPConnection.h"
#define BUFSIZE 32768
#define POLL_INTERVAL 1.0

void connectionMaster (CFReadStreamRef stream, CFStreamEventType event, void *myPtr) {
    if (event == kCFStreamEventHasBytesAvailable) {
	UInt8 buffer[BUFSIZE];
	CFIndex bytesRead = CFReadStreamRead(stream, buffer, BUFSIZE);
	if (bytesRead > 0) {
	    [(WTHTTPConnection *)myPtr handleBytes:buffer length:bytesRead];
	}
    }
    else if (event == kCFStreamEventErrorOccurred) {
	[(WTHTTPConnection *)myPtr handleError];
    }
    else if (event == kCFStreamEventEndEncountered) {
	[(WTHTTPConnection *)myPtr handleEnd];
    }
}


@implementation WTHTTPConnection

@synthesize connectionError, request, requestStream, localURL, connectionTimeout;
@synthesize delegate, connectionTimer, lastActivity;

- (id)initWithDestination:(NSURL *)destination protocol:(NSString *)protocol {
    if ([self init]) {
	bytesBeforeResume = 0;
	connectionTimeout = 60;
	destinationURL = [destination retain];
	authenticationRequired = NO;
	request = CFHTTPMessageCreateRequest(kCFAllocatorDefault,
					     (CFStringRef)protocol,
					     (CFURLRef)destinationURL,
					     kCFHTTPVersion1_1);
	if (request == NULL) {
	    [self release];
	    self = nil;
	}
    }
    return self;
}

- (void)setRequestBodyWithData:(NSData *)data {
    CFHTTPMessageSetBody(request, (CFDataRef)data);
}


- (BOOL)setRequestBodyWithTargetURL:(NSURL *)targetURL offset:(unsigned long long)offset  {
    //
    // We don't want to load files into memory (probably large, especially in iPhone).
    // And we would like to get some sort of uploading progress.
    // That's why we open here new stream instead of using setRequestBodyWithData
    //
    
    bytesBeforeResume = 0;
    unsigned long long contentLength = 0;
    NSNumber *fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[targetURL path] error:nil] valueForKey:NSFileSize];
    contentLength = [fileSize unsignedLongLongValue];
    if (!contentLength) {
	self.connectionError = [NSError errorWithDomain:@"HTTPConnection" code:4242 userInfo:nil];
	return NO;
    }
    
    bodyStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, (CFURLRef)targetURL);
    if (bodyStream == NULL) {
	self.connectionError = [NSError errorWithDomain:@"HTTPConnection" code:4202 userInfo:nil];
	return NO;
    }    
    
    // We are using Content-Range header in case we want to resume uploading.
    if (offset && offset != contentLength  ) {
	CFReadStreamSetProperty(bodyStream, kCFStreamPropertyFileCurrentOffset, (CFNumberRef)[NSNumber numberWithUnsignedLongLong:offset]);
	NSString *contentRangeValue = [NSString stringWithFormat:@"bytes %qi-%qi/%qi", offset, contentLength - 1, contentLength];
	CFHTTPMessageSetHeaderFieldValue(self.request, CFSTR("Content-Range"), (CFStringRef)contentRangeValue);
	contentLength = contentLength - offset;
	bytesBeforeResume = offset;
    }
    
    NSString *contentLengthValue = [NSString stringWithFormat:@"%qi", contentLength];    
    CFHTTPMessageSetHeaderFieldValue(self.request, CFSTR("Content-Length"), (CFStringRef)contentLengthValue);
    
    return YES;
}

- (BOOL)setAuthentication:(CFHTTPAuthenticationRef)authentication credentials:(NSDictionary *)credentials {
    if (!CFHTTPMessageApplyCredentialDictionary(request,
						authentication,
						(CFDictionaryRef)credentials,
						NULL))
    {
	self.connectionError = [NSError errorWithDomain:@"HTTPConnection" code:4203 userInfo:nil];
	return NO;
    }
    authenticationRequired = YES;
    return YES;
}

- (BOOL)openStream {
    bytesForDownload = 0;
    bytesReceived = 0;
    if ([self.delegate respondsToSelector:@selector(HTTPConnectionDidBeginEstablishingConnection:)]) {
	[self.delegate HTTPConnectionDidBeginEstablishingConnection:self];
    }
    [responseData release];
    responseData = [[NSMutableData alloc] initWithLength:0];
    if (bodyStream) {
	requestStream = CFReadStreamCreateForStreamedHTTPRequest(kCFAllocatorDefault,
								 request,
								 bodyStream);
    }
    else {
	bytesBeforeResume = 0;
	requestStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, request);
    }
    
    if (!requestStream) {
	self.connectionError = [NSError errorWithDomain:@"HTTPConnection" code:4204 userInfo:nil];
	if ([self.delegate respondsToSelector:@selector(HTTPConnectionDidFailToEstablish:)]) {
	    [self.delegate HTTPConnectionDidFailToEstablish:self];
	}
	
	return NO;
    }
    
    CFReadStreamSetProperty(requestStream, kCFStreamPropertyHTTPAttemptPersistentConnection, kCFBooleanTrue);
    
    if (CFReadStreamOpen(requestStream)) {
	self.lastActivity = [NSDate date];
	if ([self.delegate respondsToSelector:@selector(HTTPConnectionDidEstablish:)]) {
	    [self.delegate HTTPConnectionDidEstablish:self];
	}	
	//The timer is used only to poll connection about the transfer progress. Event handling is scheduled in run loop.
	self.connectionTimer = [NSTimer scheduledTimerWithTimeInterval:POLL_INTERVAL
								target:self
							      selector:@selector(pollConnection:)
							      userInfo:nil
							       repeats:YES];
	isOpen = YES;
	
	CFStreamClientContext myContext = {0, self, NULL, NULL, NULL};
	
	CFOptionFlags registeredEvents = kCFStreamEventHasBytesAvailable
	| kCFStreamEventOpenCompleted
	| kCFStreamEventCanAcceptBytes
	| kCFStreamEventErrorOccurred
	| kCFStreamEventNone
	| kCFStreamEventEndEncountered;
	if (CFReadStreamSetClient(requestStream, registeredEvents, connectionMaster, &myContext)) {
	    CFReadStreamScheduleWithRunLoop(requestStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	}
	CFRunLoopRun();
	return YES;
    }
    else {
	self.connectionError = [NSError errorWithDomain:@"HTTPConnection" code:4205 userInfo:nil];
	if ([self.delegate respondsToSelector:@selector(HTTPConnectionDidFailToEstablish:)]) {
	    [self.delegate HTTPConnectionDidFailToEstablish:self];
	}
	
	return NO;
    }
}

- (void)closeStream {
    NSLog(@"Close stream");
    if (isOpen) {
	[self pollConnection:nil];
	isOpen = NO;
	[self.connectionTimer invalidate];
	if (responseStream) {
	    [responseStream close];
	}
	CFReadStreamUnscheduleFromRunLoop(requestStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	CFReadStreamClose(requestStream);
    }
}

- (void)handleError {
    [self closeStream];
    if ([self.delegate respondsToSelector:@selector(interruptedHTTPConnection:)]) {
	[self.delegate interruptedHTTPConnection:self];
    }
}

- (void)pollConnection:(NSTimer *)aTimer {
    if (isOpen) {
	long long bytesWritten = 0;
	CFNumberRef cfSize = CFReadStreamCopyProperty(requestStream, kCFStreamPropertyHTTPRequestBytesWrittenCount);
	CFNumberGetValue(cfSize, kCFNumberLongLongType, &bytesWritten);
	CFRelease(cfSize);
	cfSize = NULL;
	if (bytesWritten > 0) {
	    self.lastActivity = [NSDate date];
	    if ([self.delegate respondsToSelector:@selector(HTTPConnection:didSendBytes:)]) {
		[self.delegate HTTPConnection:self didSendBytes:((unsigned)bytesWritten + bytesBeforeResume)];
	    }
	}
	if ([self.delegate respondsToSelector:@selector(HTTPConnection:didReceiveBytes:)]) {
	    [self.delegate HTTPConnection:self didReceiveBytes:bytesReceived];
	}
    }
    //TODO: implement timeout checking here (use lastActivity and connectionTimeout)
}

- (void)handleBytes:(UInt8 *)buffer length:(CFIndex)bytesRead {
    self.lastActivity = [NSDate date];
    bytesReceived += bytesRead;
    if (self.localURL) {
	// This is a case when we don't want to store downloaded data into memory
	// We are using stream and writing received bytes into the file if it's determined
	if (!responseStream) {
	    responseStream = [[NSOutputStream alloc] initToFileAtPath:[self.localURL path] append:NO];
	    [responseStream open];
	}
	[responseStream write:buffer maxLength:bytesRead];
    }
    else {
	[responseData appendBytes:buffer length:bytesRead];
    }
}

- (void)handleEnd {
    CFHTTPMessageRef responseHeader = (CFHTTPMessageRef)CFReadStreamCopyProperty(requestStream, kCFStreamPropertyHTTPResponseHeader);
    [self closeStream];
    
    CFStringRef statusString = CFHTTPMessageCopyResponseStatusLine(responseHeader);
    UInt32 statusCode = CFHTTPMessageGetResponseStatusCode(responseHeader);
    
    if (statusCode == 401 || statusCode == 407 ) {
	CFHTTPAuthenticationRef authentication = CFHTTPAuthenticationCreateFromResponse(kCFAllocatorDefault, responseHeader);
	if (authenticationRequired) {
	    if ([self.delegate respondsToSelector:@selector(HTTPConnection:didFailToPassAuthenticationChallenge:)]) {
		[self.delegate HTTPConnection:self didFailToPassAuthenticationChallenge:authentication];
	    }
	}
	else {
	    if ([self.delegate respondsToSelector:@selector(HTTPConnection:didReceiveAuthenticationChallenge:)]) {
		[self.delegate HTTPConnection:self didReceiveAuthenticationChallenge:authentication];
	    }
	}
	CFRelease(authentication);
	authentication = NULL;
    }
    else {
	if ([self.delegate respondsToSelector:@selector(HTTPConnection:didReceiveResponse:)]) {
	    [self.delegate HTTPConnection:self didReceiveResponse:[NSDictionary dictionaryWithObjectsAndKeys:
								   [NSNumber numberWithInt:statusCode], @"statusCode",
								   statusString, @"statusString",
								   responseData, @"responseBody",
								   nil]];
	}
    }
    
    CFRelease(statusString);
    statusString == NULL;
    CFRelease(responseHeader);
    responseHeader = NULL;
}

- (void)dealloc {
    NSLog(@"WTHTTPConnection object will be deallocated");
    if (isOpen) {
	[self closeStream];
    }
    
    [connectionTimer release];
    [responseStream release];
    [connectionError release];
    [responseData release];
    [destinationURL release];
    [localURL release];
    [lastActivity release];
    
    
    if (request) {
	CFRelease(request);
	request = NULL;
    }
    
    if (bodyStream) {
	CFRelease(bodyStream);
	bodyStream = NULL;
    }
    
    if (requestStream) {
	CFRelease(requestStream);
	requestStream = NULL;
    }    
    [super dealloc];
}


@end
