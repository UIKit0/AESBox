//
//  ABMainWindowController.m
//  AESBox
//
//  Created by Ben Gotow on 11/30/13.
//  Copyright (c) 2013 Foundry376. All rights reserved.
//

#import "ABMainWindowController.h"
#import "ABSecurePhoto.h"
#import "AESCrypt.h"
#import "ABAppDelegate.h"


@implementation ABMainWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        _createdTempFiles = [NSMutableArray array];
    }
    return self;
}

- (void)cleanupTempFiles
{
    for (NSString * path in _createdTempFiles) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
}

- (void)setURL:(NSURL *)URL
{
    _URL = URL;
    [self updateOutlineView];
}

- (void)setDisplayedURL:(NSURL *)displayedURL
{
    _displayedURL = displayedURL;
    _photos = [NSMutableArray array];

    [self withFilesInDirectory:displayedURL includingDirectories:NO perform:^(NSURL * url, BOOL isDirectory){
        if ([self isEncrypted: url])
            [_photos addObject: [[ABSecurePhoto alloc] initWithURL:url andDecryptionProvider:self]];
    }];
    [self updateBrowserView];
}

- (void)initializeWithPassword:(NSString *)password
{
    _password = password;
    
    [[ABSecurePhoto cache] removeAllObjects];
    [self updateBrowserView];
    [self updateOutlineView];
    [self updatePasswordLabel];
    [self scanForUnencryptedFiles];
}

- (IBAction)changePassword:(id)sender
{
    [[ABSecurePhoto cache] removeAllObjects];
    
    if (_encrpytionsQueued != _encrpytionsFinished) {
        NSAlert * alert = [NSAlert alertWithMessageText:@"Please wait for encryption to finish before changing the encryption password." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
        [alert runModal];
        return;
    }
    
    NSAlert * alert = [NSAlert alertWithMessageText:@"All of the files inside your root secure folder will be decrypted and re-encrypted with the new password you choose. To decrypt all your files, continue without a password." defaultButton:@"Continue" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@""];
    NSModalResponse result = [alert runModal];
    if (result != NSAlertDefaultReturn)
        return;
    
    [self reencryptWithPassword: [(ABAppDelegate*)[NSApp delegate] promptForPassphrase]];
}

- (void)reencryptWithPassword:(NSString*)newPassword
{
    NSString * oldPassword = _password;
    _password = newPassword;
    [self updatePasswordLabel];

    _encrpytionsQueued -= _encrpytionsFinished;
    _encrpytionsFinished = 0;

    [self withAllFiles: ^(NSURL * url, BOOL isEncrypted) {
        _encrpytionsQueued += 1;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData * data = [NSData dataWithContentsOfURL: url];
            NSURL * newURL = url;

            if (isEncrypted)
                data = [AESCrypt decryptData:data password: oldPassword];
            if (_password)
                data = [AESCrypt encryptData:data password: _password];

            if (!isEncrypted && _password) {
                NSString * newTitle = [NSString stringWithFormat: @"%@-e", [url lastPathComponent]];
                newURL = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:newTitle];

            } else if (isEncrypted && !_password) {
                NSString * newExtension = [[url pathExtension] stringByReplacingOccurrencesOfString:@"-e" withString:@""];
                newURL = [NSURL fileURLWithPath:[[[url path] stringByDeletingPathExtension] stringByAppendingPathExtension: newExtension]];
            }

            if (data) {
                data = [AESCrypt encryptData:data password: _password];
                [data writeToURL:newURL atomically: YES];

            } else {
                NSLog(@"Unable to decrypt %@. Probably not encrypted?", [url absoluteString]);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                _encrpytionsFinished += 1;
                [self updateEncryptionProgress];
            });
            return;
        });
    }];
    [self updateEncryptionProgress];
}

- (void)createFolderWithName:(NSString*)name
{
    name = [NSString stringWithFormat: @"==%@", [AESCrypt encrypt:name password:_password]];

    NSString * path = [[_displayedURL path] stringByAppendingPathComponent: name];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:NULL error:nil];
    [self updateOutlineView];
}

- (NSString*)nameForFolder:(NSString*)name
{
    if ([name hasPrefix: @"=="] && _password)
        name = [AESCrypt decrypt:[name substringFromIndex: 2] password:_password];
    return name;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self setDisplayedURL: _URL];
    
    [_browserView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    [_browserView setDraggingDestinationDelegate: self];
    [_encryptionProgressIndicator setHidden: YES];
    [_outlineView expandItem:_displayedFolderTree expandChildren:YES];
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    return NSDragOperationCopy;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSArray * filenames = [pboard propertyListForType:NSFilenamesPboardType];
    [self encryptFiles: filenames];
    [sender setAnimatesToDestination: YES];
    return YES;
}

- (void)scanForUnencryptedFiles
{
    if (_password == nil)
        return;
    
    BOOL __block haveEncryptedSomething = NO;
    NSMutableArray * unencryptedFiles = [NSMutableArray array];
    [self withAllFiles:^(NSURL *url, BOOL isEncrypted) {
        if (isEncrypted == NO)
            [unencryptedFiles addObject: [url path]];
        else
            haveEncryptedSomething = YES;
    }];
    if ([unencryptedFiles count] > 0) {
        NSString * msg = [NSString stringWithFormat: @"There are %d unencrypted files inside this folder. Would you like to encrypt them now?", (int)[unencryptedFiles count]];
        NSString * informative = @"";
        if (haveEncryptedSomething)
            informative = @"Only click 'Yes' if you typed in your password correctly and you can see your other images loading properly.";
        NSAlert * alert = [NSAlert alertWithMessageText:msg defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:informative, nil];
        NSModalResponse response = [alert runModal];
        if (response == NSAlertDefaultReturn)
            [self encryptFiles: unencryptedFiles];
    }
}

- (void)encryptFiles:(NSArray*)filePaths
{
    _encrpytionsQueued -= _encrpytionsFinished;
    _encrpytionsFinished = 0;
    
    int newQueued = 0;
    
    // do something with files
    for (NSString * file in filePaths) {
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDirectory];
        if (isDirectory)
            continue;
        
        // already encrypted
        if ([self isEncrypted: file])
            continue;

        _encrpytionsQueued += 1;
        newQueued += 1;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData * data = [NSData dataWithContentsOfFile: file];
            BOOL insideRootURL = [[file lowercaseString] hasPrefix: [[_URL path] lowercaseString]];
            
            // Encrypt the file
            NSData * encrypted = [AESCrypt encryptData: data password: _password];
            NSURL * encryptedURL = nil;
            
            // If the file is already within our root directory and we're encrypting it,
            // delete the original file and just append -e to the URL. If the file is outside,
            // move it into the current displayed folder.
            if (insideRootURL) {
                [[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
                encryptedURL = [NSURL fileURLWithPath: [file stringByAppendingString: @"-e"]];
                
            } else {
                NSString * encryptedFilename = [NSString stringWithFormat:@"%@-e", [file lastPathComponent]];
                encryptedURL = [_displayedURL URLByAppendingPathComponent: encryptedFilename];
            }
            
            // Make sure the file does not exist before we copy it
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath: [encryptedURL path]];
            if (!fileExists)
                [encrypted writeToURL:encryptedURL atomically: NO];

            // Create an ABSecurePhoto to represent the file or update the existing one
            dispatch_async(dispatch_get_main_queue(), ^{
                if (fileExists) {
                    NSString * msg = [NSString stringWithFormat: @"A file named %@ is already in the folder '%@', so it was not overwritten.", [file lastPathComponent], [self nameForFolder: [_displayedURL lastPathComponent]]];
                    NSAlert * alert = [NSAlert alertWithMessageText:msg defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
                    [alert runModal];
                    return;
                }
                if ([[[[encryptedURL path] stringByDeletingLastPathComponent] lowercaseString] isEqualToString: [[_displayedURL path] lowercaseString]]) {
                    [_photos addObject: [[ABSecurePhoto alloc] initWithURL:encryptedURL andDecryptionProvider:self]];
                    [self updateBrowserView];
                }
                _encrpytionsFinished += 1;
                [self updateEncryptionProgress];
            });
        });
    }
    [self updateEncryptionProgress];

    NSString * msg = [NSString stringWithFormat: @"%d files were copied in to your secure folder '%@'.", newQueued, [self nameForFolder: [_displayedURL lastPathComponent]]];
    NSAlert * alert = [NSAlert alertWithMessageText:msg defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
    [alert runModal];
}

- (void)updateEncryptionProgress
{
    [_encryptionProgressIndicator setHidden: (_encrpytionsQueued == _encrpytionsFinished)];
    [_encryptionProgressIndicator setDoubleValue: _encrpytionsFinished];
    [_encryptionProgressIndicator setMaxValue: _encrpytionsQueued];
}

- (void)updatePasswordLabel
{
    if (_password)
        [_passwordLabel setStringValue: [NSString stringWithFormat: @"Password: %@", _password]];
    else
        [_passwordLabel setStringValue: @"No Password"];
}

- (void)updateBrowserView
{
    [_photos sortUsingComparator:^NSComparisonResult(ABSecurePhoto * obj1, ABSecurePhoto * obj2) {
        return [[[obj1 URL] lastPathComponent] compare: [[obj2 URL] lastPathComponent]];
    }];
    [_browserView reloadData];

    NSString * title = [NSString stringWithFormat: @"%@ (%d)", [self nameForFolder: [_displayedURL lastPathComponent]], (int)[_photos count]];
    [self.window setTitle: title];
}

- (void)updateOutlineView
{
    _displayedFolderTree = @{@"URL": _URL, @"tree": [NSMutableArray array]};
    NSMutableArray * unsearchedNodes = [NSMutableArray arrayWithObject: _displayedFolderTree];
    
    while ([unsearchedNodes count] > 0) {
        NSDictionary * searchNode = [unsearchedNodes lastObject];
        [unsearchedNodes removeLastObject];
        
        [self withFilesInDirectory:searchNode[@"URL"] includingDirectories: YES perform:^(NSURL *url, BOOL isDirectory) {
            if (isDirectory) {
                NSDictionary * newNode = @{@"URL": url, @"tree": [NSMutableArray array]};
                [searchNode[@"tree"] addObject: newNode];
                [unsearchedNodes addObject: newNode];
            }
        }];
    }
    
    [_outlineView reloadData];
    [_outlineView expandItem:_displayedFolderTree expandChildren:YES];
}

- (void)showSlideshow
{
    NSUInteger index = [[_browserView selectionIndexes] firstIndex];
    [[IKSlideshow sharedSlideshow] runSlideshowWithDataSource:self inMode: IKSlideshowModeImages options: @{IKSlideshowStartIndex: @(index)}];
}

#pragma mark Decrypting and Opening Files

- (NSData*)decryptURL:(NSURL*)fileURL
{
    NSData * data = [NSData dataWithContentsOfURL: fileURL];
    return [AESCrypt decryptData:data password: _password];
}

- (void)openURL:(NSURL*)url slideshowIfPossible:(BOOL)slideshow
{
    NSString * extension = [[url pathExtension] lowercaseString];
    extension = [extension stringByReplacingOccurrencesOfString:@"-e" withString:@""];
    
    if (slideshow && [IMAGE_FILE_EXTENSIONS containsObject: extension])
        [self showSlideshow];
    else {
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        NSString *uuidStr = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuid);
        CFRelease(uuid);
        
        NSString * ext = [[url pathExtension] stringByReplacingOccurrencesOfString:@"-e" withString:@""];
        NSData * data = [self decryptURL: url];
        NSString * path = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat:@"%@.%@", uuidStr, ext]];
        [data writeToFile:path atomically:NO];
        [_createdTempFiles addObject: path];
        
        [[NSWorkspace sharedWorkspace] openFile: path];
    }
}

#pragma mark Key Navigation

- (void)keyDown:(NSEvent *)theEvent
{
    int code = [theEvent keyCode];
    if ((code == 49) || (code == 36)) {
        if (_showingSlideshow) {
            [[IKSlideshow sharedSlideshow] stopSlideshow: nil];
        } else {
            [self showSlideshow];
        }
    } else {
        NSLog(@"%d", code);
    }
}

#pragma mark Image Browser Data Source

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *) aBrowser
{
    return [_photos count];
}

- (id)imageBrowser:(IKImageBrowserView *) aBrowser itemAtIndex:(NSUInteger)index
{
    return [_photos objectAtIndex: index];
}

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView *) aBrowser
{
    
}

- (void)imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index
{
    NSURL * url = [[_photos objectAtIndex: index] URL];
    [self openURL: url slideshowIfPossible: YES];
}

#pragma mark Image Slideshow Data Source

- (NSUInteger)numberOfSlideshowItems
{
    return [_photos count];
}

- (id)slideshowItemAtIndex: (NSUInteger)index
{
    return [[_photos objectAtIndex: index] NSImageRepresentation];
}

- (void)slideshowDidStop
{
    _showingSlideshow = NO;
}

- (void)slideshowDidChangeCurrentIndex: (NSUInteger)newIndex
{
    [_browserView setSelectionIndexes:[NSIndexSet indexSetWithIndex: newIndex] byExtendingSelection:NO];
}

- (void)imageBrowser:(IKImageBrowserView *) aBrowser removeItemsAtIndexes:(NSIndexSet *) indexes
{
    NSAlert * alert = [NSAlert alertWithMessageText:@"Are you sure you want to delete these files?" defaultButton:@"Yes" alternateButton:@"No" otherButton:nil informativeTextWithFormat:nil];
    NSModalResponse result = [alert runModal];

    if (result == NSAlertDefaultReturn) {
        [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            ABSecurePhoto * photo = [_photos objectAtIndex: idx];
            [[NSFileManager defaultManager] removeItemAtURL: [photo URL] error:NULL];
        }];
        [_photos removeObjectsAtIndexes: indexes];
    }
}

- (NSUInteger)imageBrowser:(IKImageBrowserView *) aBrowser writeItemsAtIndexes:(NSIndexSet *) itemIndexes toPasteboard:(NSPasteboard *)pasteboard
{
    [pasteboard declareTypes: [NSMutableArray arrayWithObject: NSTIFFPboardType] owner: nil];

    ABSecurePhoto * photo = [_photos objectAtIndex: [itemIndexes firstIndex]];
    [pasteboard setData:[[photo NSImageRepresentation] TIFFRepresentation] forType: NSTIFFPboardType];
    return 1;
}

#pragma mark Outline View

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil)
        return 1;
    return [item[@"tree"] count];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (item == nil)
        return _displayedFolderTree;
    return [item[@"tree"] objectAtIndex: index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return ([item[@"tree"] count] > 0);
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    return [self nameForFolder: [[item objectForKey: @"URL"] lastPathComponent]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    [self setDisplayedURL: [item objectForKey: @"URL"]];
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return NO;
}

#pragma mark Convenience Functions

- (void)withFilesInDirectory:(NSURL*)directoryURL includingDirectories:(BOOL)withDirectories perform:(void(^)(NSURL * url, BOOL isDirectory))callback
{
    NSError *error;
    NSNumber *isDirectory = nil;

    NSArray * urls = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directoryURL includingPropertiesForKeys:@[(id)kCFURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    for (NSURL *url in urls) {
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
        
        if ([isDirectory boolValue] && withDirectories)
            callback(url, YES);
        else if ([isDirectory boolValue] == NO)
            callback(url, NO);
    }
}

- (void)withAllFiles:(void(^)(NSURL * url, BOOL isEncrypted))callback
{
    NSArray *keys = @[NSURLIsDirectoryKey];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: _URL includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^(NSURL *url, NSError *error) {
        return YES;
    }];
    
    for (NSURL * url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
        if ([isDirectory boolValue] == YES)
            continue;
        callback(url, [self isEncrypted: url]);
    }
}

- (ABSecurePhoto*)displayedPhotoWithURL:(NSURL*)url
{
    for (ABSecurePhoto * photo in _photos) {
        if ([[photo URL] isEqual: url])
            return photo;
    }
    return nil;
}

- (BOOL)isEncrypted:(id)urlOrString
{
    return [[urlOrString pathExtension] hasSuffix: @"-e"];
}



@end
