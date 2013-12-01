//
//  ABAppDelegate.h
//  AESBox
//
//  Created by Ben Gotow on 11/30/13.
//  Copyright (c) 2013 Foundry376. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ABMainWindowController.h"

@interface ABAppDelegate : NSObject <NSApplicationDelegate>
{
}
@property (assign) IBOutlet NSWindow * window;

@property (nonatomic, strong) ABMainWindowController * mainController;

- (NSString*)promptForPassphrase;

@end
