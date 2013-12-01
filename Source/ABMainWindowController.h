//
//  ABMainWindowController.h
//  AESBox
//
//  Created by Ben Gotow on 11/30/13.
//  Copyright (c) 2013 Foundry376. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface ABMainWindowController : NSWindowController <IKSlideshowDataSource, NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    NSMutableArray * _createdTempFiles;
    NSMutableArray * _photos;
    int _encrpytionsQueued;
    int _encrpytionsFinished;
    BOOL _showingSlideshow;
}

@property (weak) IBOutlet IKImageBrowserView * browserView;
@property (weak) IBOutlet NSTextField *passwordLabel;
@property (weak) IBOutlet NSProgressIndicator *encryptionProgressIndicator;
@property (weak) IBOutlet NSOutlineView *outlineView;

@property (nonatomic, strong) NSURL * URL;
@property (nonatomic, strong) NSDictionary * displayedFolderTree;
@property (nonatomic, strong) NSURL * displayedURL;
@property (nonatomic, strong) NSString * password;

#pragma mark Decrypting Files

- (id)initWithWindow:(NSWindow *)window;

- (void)cleanupTempFiles;

- (void)setURL:(NSURL *)URL;
- (void)setDisplayedURL:(NSURL *)displayedURL;

- (void)initializeWithPassword:(NSString *)password;
- (IBAction)changePassword:(id)sender;
- (void)reencryptWithPassword:(NSString*)newPassword;

- (void)createFolderWithName:(NSString*)name;

- (void)scanForUnencryptedFiles;
- (void)encryptFiles:(NSArray*)filePaths;
- (void)updateEncryptionProgress;
- (void)updatePasswordLabel;
- (void)updateBrowserView;
- (void)updateOutlineView;
- (void)showSlideshow;

#pragma mark Decrypting and Opening Files

- (NSData*)decryptURL:(NSURL*)fileURL;
- (void)openURL:(NSURL*)url slideshowIfPossible:(BOOL)slideshow;


@end
