//
//  ABAppDelegate.m
//  AESBox
//
//  Created by Ben Gotow on 11/30/13.
//  Copyright (c) 2013 Foundry376. All rights reserved.
//

#import "ABAppDelegate.h"
#import "ABMainWindowController.h"

@implementation ABAppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    if (!_mainController) {
        // prompt the user to open a folder
        NSOpenPanel * open = [NSOpenPanel openPanel];
        [open setCanChooseDirectories: YES];
        [open setCanChooseFiles: NO];
        NSInteger result = [open runModal];
        if (result == NSFileHandlingPanelOKButton) {
            _mainController = [[ABMainWindowController alloc] initWithWindowNibName:@"ABMainWindowController"];
            [_mainController setURL: [open URL]];
        } else {
            [NSApp terminate: nil];
            return;
        }
        [_mainController.window makeKeyAndOrderFront: nil];
        [_mainController initializeWithPassword: [self promptForPassphrase]];
    }
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    if (!_mainController)
        _mainController = [[ABMainWindowController alloc] initWithWindowNibName:@"ABMainWindowController"];

    NSString * folder = [filename stringByDeletingLastPathComponent];
    if ([[[[_mainController URL] path] lowercaseString] hasPrefix: [folder lowercaseString]])
        [_mainController setDisplayedURL: [NSURL fileURLWithPath: folder]];
    else
        [_mainController setURL: [NSURL fileURLWithPath: folder]];
    
    [_mainController.window makeKeyAndOrderFront: nil];
    if (_mainController.password == nil)
        [_mainController initializeWithPassword: [self promptForPassphrase]];
    [_mainController openURL: [NSURL fileURLWithPath: filename] slideshowIfPossible: NO];
    
    return YES;
}

- (void)applicationWillBecomeActive:(NSNotification *)notification
{
    [_mainController setURL: [_mainController URL]];
    [_mainController setDisplayedURL: [_mainController displayedURL]];
    [_mainController scanForUnencryptedFiles];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    // delete any unencrypted files we've created
    [_mainController cleanupTempFiles];
}

- (NSString*)promptForPassphrase
{
    // prompt the user to provide their password for the folder
    NSAlert *alert = [NSAlert alertWithMessageText:@"Type a Password" defaultButton:@"OK" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@""];
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 295, 24)];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        if ([[input stringValue] length] > 0)
            return [input stringValue];
        else
            return nil;
    } else {
        [NSApp terminate: nil];
        return nil;
    }
}

- (IBAction)createNewFolder:(id)sender
{
    // prompt the user to provide their password for the folder
    NSAlert *alert = [NSAlert alertWithMessageText:@"Create a New Folder" defaultButton:@"OK" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@""];
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 295, 24)];
    [alert setAccessoryView:input];
    NSInteger button = [alert runModal];
    if ((button == NSAlertDefaultReturn) && ([[input stringValue] length] > 0))
        [_mainController createFolderWithName: [input stringValue]];
}

@end
