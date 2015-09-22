//
//  AVAudioPlayer+Filesystem.m
//  pomodorable
//
//  Created by Kyle kinkade on 2/23/13.
//  Copyright (c) 2013 Monocle Society LLC. All rights reserved.
//

#import "AVAudioPlayer+Filesystem.h"

@implementation AVAudioPlayer (Filesystem)

+ (AVAudioPlayer *)soundForFilename:(NSString *)filename
{
    AVAudioPlayer *returnSound = nil;
    
    NSString *fileName = [filename stringByDeletingPathExtension];
    //most likely is
    NSString *lul = [[NSBundle mainBundle] pathForResource:fileName ofType:[filename pathExtension]];
    NSData *fileData = [NSData dataWithContentsOfFile:lul];
    returnSound = [[AVAudioPlayer alloc] initWithData:fileData error:NULL];
    
    //someone using custom sounds? how unlikely!
    if(!returnSound)
    {
        fileData = [NSData dataWithContentsOfFile:filename];
        returnSound = [[AVAudioPlayer alloc] initWithData:fileData error:NULL];
    }
    
    float volume = [[NSUserDefaults standardUserDefaults] floatForKey:@"audioVolume"] / 100.0f;
    [returnSound setVolume:volume];
    return returnSound;
}

+ (AVAudioPlayer *)soundForPreferenceKey:(NSString *)preferenceKey
{
    NSString *audioPath = [[NSUserDefaults standardUserDefaults] stringForKey:preferenceKey];
    return [self soundForFilename:audioPath];
}

@end
