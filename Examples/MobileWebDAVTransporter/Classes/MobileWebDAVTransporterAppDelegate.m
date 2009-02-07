//  
//  MobileWebDAVTransporterAppDelegate.m
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

#import "MobileWebDAVTransporterAppDelegate.h"
#import "TestController.h"

@implementation MobileWebDAVTransporterAppDelegate

@synthesize window;


- (void)applicationDidFinishLaunching:(UIApplication *)application {    
    testController = [[TestController alloc] initWithNibName:@"TestOptionsView" bundle:nil];
    [window addSubview:testController.view];
    [window makeKeyAndVisible];
}


- (void)dealloc {
    [testController release];
    [window release];
    [super dealloc];
}


@end
