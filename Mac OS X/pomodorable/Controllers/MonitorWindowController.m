//
//  MonitorWindowController.m
//  pomodorable
//
//  Created by Kyle Kinkade on 11/23/11.
//  Copyright (c) 2011 Monocle Society LLC All rights reserved.
//

#import "MonitorWindowController.h"
#import "AppDelegate.h"
#import "AVAudioPlayer+Filesystem.h"


// EGG animation
// height: 150
// width: 180

@implementation MonitorWindowController

#pragma mark - 

- (id)init
{
    if(self = [super initWithWindowNibName:@"MonitorNormalWindowController"])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroRequested:) name:EGG_REQUESTED object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroTimeStarted:) name:EGG_START object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroClockTicked:) name:EGG_TICK object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroTimeCompleted:) name:EGG_COMPLETE object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroStopped:) name:EGG_STOP object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalInterruptionKeyed:) name:@"externalInterruptionKeyed" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internalInterruptionKeyed:) name:@"internalInterruptionKeyed" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pomodoroPaused:) name:EGG_PAUSE object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pomodoroResume:) name:EGG_RESUME object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(floatLevelChanged:) name:@"monitorWindowOnTop" object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)windowDidLoad
{
    //set our window up
    NSNumber *floatWindow = [[NSUserDefaults standardUserDefaults] objectForKey:@"monitorWindowOnTop"];
    
    if((!floatWindow) || [floatWindow boolValue])
    {
        [self.window setLevel:NSFloatingWindowLevel];
    }
    else
    {
        [self.window setLevel:NSNormalWindowLevel];
    }
    
    [self.window setAcceptsMouseMovedEvents:YES];
    [self.window setMovableByWindowBackground:YES];
    [self.window setOpaque:NO];
    [self.window setBackgroundColor:[NSColor clearColor]];
    [self.window setIgnoresMouseEvents:YES];
    
    //NSTrackingMouseMoved
    //add tracking area to containerView, so we can do the swap thingy 
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[self.window frame] options:NSTrackingMouseEnteredAndExited | NSTrackingInVisibleRect | NSTrackingActiveAlways owner:self userInfo:nil];
    [containerView addTrackingArea:area];
    
    //create shadow for view
    NSView *mainView = (NSView *)self.window.contentView;
    [mainView setWantsLayer:YES];
    CGColorRef shadowColor = CGColorCreateGenericRGB(0, 0, 0, 1);
    mainView.layer.shadowRadius = 5;
    mainView.layer.shadowOpacity = .5;
    mainView.layer.shadowColor = shadowColor;
    CGColorRelease(shadowColor);

    //set up normal layer
    [containerView addSubview:normalView];
    
    //set up backgroundImages for views
    normalView.backgroundImage = [NSImage imageNamed:@"focus-card"];
    mouseoverView.backgroundImage = [NSImage imageNamed:@"focus-card-hover"];
    [self.window close];
    
    //stop button text
    //center the text    
    NSMutableParagraphStyle *pStyle = [[NSMutableParagraphStyle alloc] init];    
    pStyle.alignment = NSCenterTextAlignment;
    NSColor *txtColor = [NSColor whiteColor];
    NSFont *txtFont = [NSFont systemFontOfSize:12];
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowOffset:NSMakeSize(0.0,-1.0)];
    [shadow setShadowBlurRadius:1.0];
    [shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.7]];
    
    NSDictionary *txtDict = [NSDictionary dictionaryWithObjectsAndKeys:pStyle, NSParagraphStyleAttributeName, txtFont, NSFontAttributeName, txtColor,  NSForegroundColorAttributeName, shadow, NSShadowAttributeName, nil];
    stopString = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"Stop", @"Stop") attributes:txtDict];
    resumeString = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"Resume",@"Resume") attributes:txtDict];
    [stopButton setAttributedTitle:stopString];
    
    //set up hatching sounds
    //hatchsound1
    NSString *lul = [[NSBundle mainBundle] pathForResource:@"4_egg_nudge_1" ofType:@"aif"];
    NSData *fileData = [NSData dataWithContentsOfFile:lul];
    hatchSound1 = [[AVAudioPlayer alloc] initWithData:fileData error:NULL];
    hatchSound1.volume = .5;
    [hatchSound1 prepareToPlay];
    
    //hatchSound2
    lul = [[NSBundle mainBundle] pathForResource:@"6_egg_nudge_2" ofType:@"aif"];
    fileData = [NSData dataWithContentsOfFile:lul];
    hatchSound2 = [[AVAudioPlayer alloc] initWithData:fileData error:NULL];
    hatchSound2.volume = .5;
    [hatchSound2 prepareToPlay];
    
    //hatchSound3
    lul = [[NSBundle mainBundle] pathForResource:@"8_egg_nudge_3" ofType:@"aif"];
    fileData = [NSData dataWithContentsOfFile:lul];
    hatchSound3 = [[AVAudioPlayer alloc] initWithData:fileData error:NULL];
    hatchSound3.volume = .5;
    [hatchSound3 prepareToPlay];

}

#pragma mark - IBActions

- (IBAction)addExternalInterruption:(id)sender;
{
    id s = sender;
    if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask))
        s = nil;
            
    AppDelegate *appDelegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [appDelegate externalInterruptionKeyed:s];
}

- (IBAction)addInternalInterruption:(id)sender;
{
    id s = sender;
    if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask))
        s = nil;
    
    AppDelegate *appDelegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [appDelegate internalInterruptionKeyed:s];
}

- (IBAction)stopPomodoro:(id)sender;
{
    EggTimer *Timer = [EggTimer currentTimer];
    
    switch(Timer.status)
    {
        case TimerStatusPaused:
            [Timer resume];
            break;
        case TimerStatusRunning:
            [Timer stop];
            break;
        case TimerStatusStopped:
            break;
    }
}

#pragma mark - NSTrackingArea Methods

- (void)replaceView:(NSView *)oldView withView:(NSView *)newView
{
    //remove old view
    [oldView removeFromSuperview];
    
    //add in new view
    [containerView addSubview:newView];
    
    CATransition *t = [CATransition animation];
    t.duration = .25;
    t.type = kCATransitionFade;
    [containerView.layer addAnimation:t forKey:@"fade in"];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    [self.window setIgnoresMouseEvents:NO];
    EggTimer *currentTimer = [EggTimer currentTimer];
    TimerStatus timerStatus = [currentTimer status];
    if((timerStatus == TimerStatusRunning || timerStatus == TimerStatusPaused) && currentTimer.type == TimerTypeEgg)
    {
        [self replaceView:normalView withView:mouseoverView];
    }
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [self.window setIgnoresMouseEvents:YES];
    [self replaceView:mouseoverView withView:normalView];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
}

#pragma mark - custom methods

- (void)updatePomodoroCount
{
    pomodoroCount.stringValue = [NSString stringWithFormat:@"%d", (int)[[Activity currentActivity].completedEggs count], nil];
    plannedPomodoroCount.stringValue = [[Activity currentActivity].plannedCount stringValue];
}

#pragma mark - Notification Methods

- (void)PomodoroRequested:(NSNotification *)note
{
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"displayMonitorWindow"])
    [self.window makeKeyAndOrderFront:nil];

    Activity *a = [Activity currentActivity];
    self.currentActivity = a;
    
    NSDictionary *bindingOptions = @{ NSContinuouslyUpdatesValueBindingOption : @YES };
    [ribbonView bind:@"plannedPomodoroCount"
            toObject:self
         withKeyPath:@"currentActivity.plannedCount"
             options:bindingOptions];
    
    [ribbonView bind:@"completePomodoroCount"
            toObject:self
         withKeyPath:@"currentActivity.completedEggs.@count"
             options:bindingOptions];
    
    [ribbonView bind:@"completed"
            toObject:a
         withKeyPath:@"completed"
             options:bindingOptions];
    
    //make *damn* sure the button is stopped.
    [stopButton setAttributedTitle:stopString];
    stopButton.image = [NSImage imageNamed:@"button-stop"];
    stopButton.alternateImage = [NSImage imageNamed:@"button-stop-down"];
    
    //remove all animations
    NSView *mainView = (NSView *)self.window.contentView;
    [mainView.layer removeAllAnimations]; 
    
    //populate activity name
    //activityNameLabel.stringValue = a.name;
    [activityNameLabel bind:@"stringValue"
                   toObject:self
                withKeyPath:@"currentActivity.name"
                    options:bindingOptions];
    
    //populate pomodoro counts
    [self updatePomodoroCount];
    
    //populate interruptions
    internalInterruptionLabel.stringValue = [[[Activity currentActivity] internalInterruptionCount] stringValue];
    externalInterruptionLabel.stringValue = [[[Activity currentActivity] externalInterruptionCount] stringValue];

    [containerView.layer removeAllAnimations];
}

- (void)PomodoroTimeStarted:(NSNotification *)note
{
    EggTimer *egg = (EggTimer *)[note object];
    _timeEstimated = (double)egg.timeEstimated;
    if (egg.type == TimerTypeEgg) {
        if(![[NSUserDefaults standardUserDefaults] boolForKey:@"hideMonitorAnimation"])
            [hatchSound1 performSelectorInBackground:@selector(play) withObject:nil];
    }
}

- (void)PomodoroClockTicked:(NSNotification *)note
{
    EggTimer *pomo = (EggTimer *)[note object];
    
    int diff = pomo.timeEstimated - pomo.timeElapsed;
    
    int minutesLeft = diff / 60;
    int secondsleft = diff % 60;
    
    NSString *stringFormat = @"%02d:%02d";
    timerLabel.stringValue = [NSString stringWithFormat:stringFormat, minutesLeft, secondsleft, nil];
}

- (void)PomodoroTimeCompleted:(NSNotification *)note
{
    EggTimer *pomo = (EggTimer *)[note object];
    if(pomo.type == TimerTypeEgg)
    {
        [self updatePomodoroCount];
        
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:60];
        [arr addObjectsFromArray:[[NSBundle mainBundle] pathsForResourcesOfType:@"png" inDirectory:@"egg_sequences/10_egg_hatch"]];
        [arr addObjectsFromArray:[[NSBundle mainBundle] pathsForResourcesOfType:@"png" inDirectory:@"egg_sequences/11_egg_out"]];

        AppDelegate *appDelegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
        
        if(![[NSUserDefaults standardUserDefaults] boolForKey:@"hideMonitorAnimation"])
            [appDelegate.windUpSound performSelectorInBackground:@selector(play) withObject:nil];

        [self mouseExited:nil];
    }
    
    if(pomo.type == TimerTypeLongBreak || pomo.type == TimerTypeShortBreak)
    {
        if(![[NSUserDefaults standardUserDefaults] boolForKey:@"autoStartNextTimer"])
            [self.window close];
    }
    
    [stopButton setAttributedTitle:stopString];
    stopButton.image = [NSImage imageNamed:@"button-stop"];
    stopButton.alternateImage = [NSImage imageNamed:@"button-stop-down"];
}

- (void)PomodoroStopped:(NSNotification *)note
{
    EggTimer *pomo = (EggTimer *)[note object];
    if(pomo.type == TimerTypeEgg)
    {
        [self.window close];
    }
    
    [stopButton setAttributedTitle:stopString];
    stopButton.image = [NSImage imageNamed:@"button-stop"];
    stopButton.alternateImage = [NSImage imageNamed:@"button-stop-down"];
}

- (void)pomodoroPaused:(NSNotification *)note
{
    [stopButton setAttributedTitle:resumeString];
    stopButton.image = [NSImage imageNamed:@"button-resume"];
    stopButton.alternateImage = [NSImage imageNamed:@"button-resume-down"];
}

- (void)pomodoroResume:(NSNotificationCenter *)note
{
    [stopButton setAttributedTitle:stopString];
    stopButton.image = [NSImage imageNamed:@"button-stop"];
    stopButton.alternateImage = [NSImage imageNamed:@"button-stop-down"];
}

- (void)externalInterruptionKeyed:(NSNotification *)note
{
    externalInterruptionLabel.stringValue = [[[Activity currentActivity] externalInterruptionCount] stringValue];
}

- (void)internalInterruptionKeyed:(NSNotification *)note
{
    internalInterruptionLabel.stringValue = [[[Activity currentActivity] internalInterruptionCount] stringValue];
}

- (void)floatLevelChanged:(NSNotification *)note
{
    //set our window up
    NSNumber *floatWindow = [[NSUserDefaults standardUserDefaults] objectForKey:@"monitorWindowOnTop"];
    
    if((!floatWindow) || [floatWindow boolValue])
    {
        [self.window setLevel:NSFloatingWindowLevel];
    }
    else
    {
        [self.window setLevel:NSNormalWindowLevel];
    }
}

@end
