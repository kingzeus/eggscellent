//
//  NotificationsPreferencesViewController.h
//  pomodorable
//
//  Created by Kyle Kinkade on 11/22/11.
//  Copyright (c) 2011 Monocle Society LLC All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MASPreferencesViewController.h"

FOUNDATION_EXPORT NSString *kPlayAttentionCheckSound;

@interface NotificationsPreferencesViewController : NSViewController <MASPreferencesViewController, NSSoundDelegate>
{
    IBOutlet NSPopUpButton *tickSelection;
    IBOutlet NSPopUpButton *pomodoroCompletion;
    IBOutlet NSPopUpButton *breakCompletion;
    IBOutlet NSSlider      *volumeSlider;
    
    NSArray *ticks;
    NSArray *completions;
    NSArray *customs;
    NSSound *previewSound;
    
    NSURL *hackURL;
}
@property (nonatomic, unsafe_unretained) NSWindow *window;

@property (weak) IBOutlet NSButton *attentionCheckButton;

- (IBAction)actionAttentionCheckToggle:(NSButton *)sender;
- (IBAction)newTickSoundSelected:(id)sender;
- (IBAction)newCompletedSoundSelected:(id)sender;
- (IBAction)volumeChange:(id)sender;

@end
