//
//  ABSecurePhoto.m
//  AESBox
//
//  Created by Ben Gotow on 11/30/13.
//  Copyright (c) 2013 Foundry376. All rights reserved.
//

#import "ABSecurePhoto.h"
#import "AESCrypt.h"
#import "ABMainWindowController.h"
#import <Quartz/Quartz.h>
#import <AVFoundation/AVFoundation.h>

static NSCache * _securePhotoDataCache;
static NSData *  _undecryptableData;

@implementation ABSecurePhoto

+ (NSCache*)cache
{
    if (!_securePhotoDataCache) {
        _securePhotoDataCache = [[NSCache alloc] init];
        [_securePhotoDataCache setTotalCostLimit: 1024*1024*150]; // 150MB
    }
    return _securePhotoDataCache;
}

- (id)initWithURL:(NSURL*)URL andDecryptionProvider:(ABMainWindowController*)decryptionProvider
{
    self = [super init];
    if (self) {
        _decryptionProvider = decryptionProvider;
        _URLVersion = 1;
        _URL = URL;
    }
    return self;
}

- (NSData*)decryptedData
{
    NSData * decrypted = [[ABSecurePhoto cache] objectForKey: _URL];
    if (!decrypted) {
        decrypted = [_decryptionProvider decryptURL: _URL];
        [[ABSecurePhoto cache] setObject:decrypted forKey:_URL cost:[decrypted length]];
    }
    if (decrypted)
        return decrypted;
    else {
        if (!_undecryptableData)
            _undecryptableData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource:@"undecryptable" ofType:@"png"]];
        return _undecryptableData;
    }
}

- (NSString *)imageUID
{
    return [_URL absoluteString];
}

- (NSString *)imageRepresentationType;
{
    NSString * extension = [[_URL pathExtension] lowercaseString];
    extension = [extension stringByReplacingOccurrencesOfString:@"-e" withString:@""];
    
    if ([IMAGE_FILE_EXTENSIONS containsObject: extension])
        return IKImageBrowserNSDataRepresentationType;
    else
        return IKImageBrowserNSImageRepresentationType;
}


- (id)imageRepresentation
{
    NSString * extension = [[_URL pathExtension] lowercaseString];
    extension = [extension stringByReplacingOccurrencesOfString:@"-e" withString:@""];
    
    if ([IMAGE_FILE_EXTENSIONS containsObject: extension]) {
        return [self decryptedData];
        
    } else {
        return [[NSWorkspace sharedWorkspace] iconForFileType: extension];
    }
}

- (NSImage*)NSImageRepresentation
{
    return [[NSImage alloc] initWithData: [self decryptedData]];
}

- (CGImageRef)CGImageRepresentationWithProperties:(NSDictionary**)fileProps
{
    // Get the URL for the pathname passed to the function.
    CGImageRef        myImage = NULL;
    CGImageSourceRef  myImageSource;
    CFDictionaryRef   myOptions = NULL;
    CFStringRef       myKeys[2];
    CFTypeRef         myValues[2];
    
    // Set up options if you want them. The options here are for
    // caching the image in a decoded form and for using floating-point
    // values if the image format supports them.
    myKeys[0] = kCGImageSourceShouldCache;
    myValues[0] = (CFTypeRef)kCFBooleanTrue;
    myKeys[1] = kCGImageSourceShouldAllowFloat;
    myValues[1] = (CFTypeRef)kCFBooleanTrue;

    // Create the dictionary
    myOptions = CFDictionaryCreate(NULL, (const void **) myKeys, (const void **) myValues, 2, &kCFTypeDictionaryKeyCallBacks, & kCFTypeDictionaryValueCallBacks);
    // Create an image source from the URL.
    myImageSource = CGImageSourceCreateWithData((__bridge CFDataRef)[self imageRepresentation], myOptions);
    CFRelease(myOptions);
    // Make sure the image source exists before continuing
    if (myImageSource == NULL){
        fprintf(stderr, "Image source is NULL.");
        return  NULL;
    }
    // Create an image from the first item in the image source.
    myImage = CGImageSourceCreateImageAtIndex(myImageSource, 0, NULL);
    if (fileProps)
        *fileProps = (__bridge NSDictionary *)(CGImageSourceCopyProperties(myImageSource, nil));

    CFRelease(myImageSource);
    // Make sure the image exists before continuing
    if (myImage == NULL){
        fprintf(stderr, "Image not created from image source.");
        return NULL;
    }
    return myImage;
}

- (NSUInteger)imageVersion
{
    return _URLVersion;
}

- (NSString *)imageTitle
{
    return [[_URL absoluteString] lastPathComponent];
}

- (NSString *)imageSubtitle
{
    return nil;
}

- (BOOL) isSelectable
{
    return YES;
}

@end
