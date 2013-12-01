//
//  ABSecurePhoto.h
//  AESBox
//
//  Created by Ben Gotow on 11/30/13.
//  Copyright (c) 2013 Foundry376. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>

@class ABMainWindowController;

@interface ABSecurePhoto : NSObject

@property (nonatomic, weak)  ABMainWindowController * decryptionProvider;
@property (nonatomic, assign) int URLVersion;
@property (nonatomic, strong) NSURL * URL;

+ (NSCache*)cache;

- (id)initWithURL:(NSURL*)URL andDecryptionProvider:(ABMainWindowController*)decryptionProvider;

- (id)imageRepresentation;
- (CGImageRef)CGImageRepresentationWithProperties:(NSDictionary**)fileProps;
- (NSImage*)NSImageRepresentation;

@end
