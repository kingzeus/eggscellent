//
//  MonitorWindowController.h
//  pomodorable
//
//  Created by Kyle Kinkade on 11/23/11.
//  Copyright (c) 2011 Monocle Society LLC All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

#import "ModelStore.h"
#import "ColorView.h"
#import "RoundedBox.h"
#import "TaskRibbonView.h"
#import "BackgroundView.h"
#import "NSAnimatedImageView.h"

@interface MonitorWindowController : NSWindowController <NSAnimatedImageViewDelegate>
{
    //general items
    IBOutlet NSView                 *growmatoView;
    IBOutlet NSView                 *containerView;
    IBOutlet TaskRibbonView         *ribbonView;
    IBOutlet NSTextField            *pomodoroCount;
    IBOutlet NSTextField            *plannedPomodoroCount;
    
    //mouseover view items
    IBOutlet BackgroundView         *mouseoverView;
    IBOutlet NSTextField            *timerLabel;
    IBOutlet NSTextField            *internalInterruptionLabel;
    IBOutlet NSTextField            *externalInterruptionLabel;
    IBOutlet NSButton               *stopButton;
    
    //non-mouseover view items
    IBOutlet BackgroundView         *normalView;
    IBOutlet NSTextField            *activityNameLabel;
    
    NSAttributedString              *stopString;
    NSAttributedString              *resumeString;
    
    AVAudioPlayer                   *hatchSound1;
    AVAudioPlayer                   *hatchSound2;
    AVAudioPlayer                   *hatchSound3;
    
    double                          _timeEstimated;
}
@property (strong) Activity *currentActivity;
@property (strong) NSString *currentName;


- (IBAction)addExternalInterruption:(id)sender;
- (IBAction)addInternalInterruption:(id)sender;
- (IBAction)stopPomodoro:(id)sender;

@end
