//  
//  MobileWebDAVTransporterAppDelegate.h
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

@class TestController;

@interface MobileWebDAVTransporterAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    TestController *testController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@end

