//
//  AppDelegate.m
//  pomodorable
//
//  Created by Kyle Kinkade on 11/5/11.
//  Copyright (c) 2011 Monocle Society LLC All rights reserved.
//
#import <ServiceManagement/ServiceManagement.h>
//#import <RobotKit/RobotKit.h>

#import "AppDelegate.h"
#import "ModelStore.h"
#import "Activity.h"
#import "OverviewViewController.h"

#import "SGHotKeyCenter.h"
#import "GeneralPreferencesViewController.h"
#import "ShortcutsPreferencesViewController.h"
#import "NotificationsPreferencesViewController.h"
#import "IntegrationPreferencesViewController.h"
#import "CalendarPreferencesViewController.h"
#import "DevicesPreferencesViewController.h"
#import "WelcomeWindowController.h"
#import "RemoteClientController.h"

#import "EggTimer.h"
#import "ScriptManager.h"
#import "AVAudioPlayer+Filesystem.h"

#ifdef CLASSIC_APP
#import <Sparkle/Sparkle.h>

@implementation AppDelegate (classic)

@end
#endif

void *kContextActivePanel = &kContextActivePanel;
@implementation AppDelegate
@synthesize panelController;
@synthesize taskSyncController;
@synthesize hotKeyExternalInterrupt;
@synthesize hotKeyInternalInterrupt;
@synthesize hotKeyStopPomodoro;
@synthesize hotKeyToggleStatusItemWindow;
@synthesize hotKeyToggleHoverWindow;
@synthesize hotKeyToggleNoteWindow;
@synthesize windUpSound;
@synthesize tickSound;
@synthesize pomodoroCompleteSound;
@synthesize breakCompleteSound;

#pragma mark - Application delegate and notifications

- (void) showMainApplicationWindow
{
    // launch the main app window
    // remember not to automatically show the main window if using NIBs
    [panelController.window makeFirstResponder: nil];
    [panelController.window makeKeyAndOrderFront:nil];
}

//- (void)applicationWillBecomeActive:(NSNotification *)notification;
//{
//    [taskSyncController sync];
//    [[self panelController] openPanel];
//}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
//    //setup timebomb
//    NSDate *endDate = [NSDate dateWithString:@"2013-7-15 12:00:00 +0000"];
//    NSDate *today = [NSDate date];
//    if([today earlierDate:endDate] == endDate)
//    {
//        [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
//    }
    
    //Status View
    [self setupStatusView];
    
    //Notifications and Defaults
    [self setupNotificationsAndDefaults];
    
    //set up chat integration controller
    chatController = [[ChatController alloc] init];
    
    //Calendar Controller
    calendarController = [[CalendarController alloc] init];
    
    //get sync type
    [self setupTaskSyncing];
    
    //load helper window if it's turned on in preferences
    BOOL shouldLoadHelperWindow = [[NSUserDefaults standardUserDefaults] boolForKey:@"displayMonitorWindow"];
    [self loadHelperWindow:shouldLoadHelperWindow withNormalSize:YES];
    
    //this is our idle timer to check if someone went idle
    if([[NSUserDefaults standardUserDefaults] integerForKey:@"idleNudgePreference"])
    {
        idleTime = [[IdleTime alloc] init];
        idleTimer = [NSTimer timerWithTimeInterval:5 
                                        target:self 
                                      selector:@selector(idleHeartbeat) 
                                      userInfo:nil 
                                       repeats:YES];
        
        [[NSRunLoop currentRunLoop] addTimer:idleTimer forMode:NSRunLoopCommonModes];
    }
    
    //if first load, show welcome window
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"finishedFirstRun"])
    {
        //call panelController, just to make it load on init 
        [[self panelController] openPanel];
        //[[self windowController] showWindow:self];
    }
    else 
    {
        [self performSelector:@selector(displayWelcome) withObject:nil afterDelay:.1];
    }
    
    NSString *lul = [[NSBundle mainBundle] pathForResource:@"2_egg_wind" ofType:@"aif"];
    NSData *fileData = [NSData dataWithContentsOfFile:lul];
    windUpSound = [[AVAudioPlayer alloc] initWithData:fileData error:NULL];
    windUpSound.volume = .1;
    [windUpSound prepareToPlay];
    
    //if sphero, then try to connect
   // [[RKRobotProvider sharedRobotProvider] performSelector:@selector(openRobotConnection) withObject:nil afterDelay:0.1f];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{    
    // Save changes in the application's managed object context before the application terminates.
    [[ModelStore sharedStore] save];
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:RKDeviceConnectionOnlineNotification object:nil];

    // Close the connection
//    if(robotOnline)
//        [self endStreaming];
    
    return NSTerminateNow;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window 
{
    return [[[ModelStore sharedStore] managedObjectContext] undoManager];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:ACTIVITY_MODIFIED];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

#ifdef __MAC_10_8
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification;
{
    return YES;
}
#endif

#pragma mark - ApplicationDidFinishLaunching Methods

- (void)setupStatusView
{
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:STATUS_ITEM_VIEW_DEFAULT_WIDTH];
    statusView = [[StatusItemView alloc] initWithStatusItem:statusItem];
    statusView.image = [NSImage imageNamed:@"status"];
    statusView.target = self;
    statusView.action = @selector(togglePanel:);
}

- (void)setupNotificationsAndDefaults
{
#ifdef __MAC_10_8
    //set up user notifications
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;
#endif
    
    //set up Application Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:NSApplicationDidBecomeActiveNotification object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskManagerTypeChanged:) name:@"taskManagerTypeChanged" object:nil];
    
    //set up Timer notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroTimeStarted:) name:EGG_START object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroClockTicked:) name:EGG_TICK object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroTimeCompleted:) name:EGG_COMPLETE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroStopped:) name:EGG_STOP object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PomodoroRequested:) name:EGG_REQUESTED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pomodoroPaused:) name:EGG_PAUSE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pomodoroResume:) name:EGG_RESUME object:nil];
    
    //set up Activity
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ActivityModifiedCompletion:) name:ACTIVITY_MODIFIED object:nil];
    
    //set up Idle Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(awokeFromIdle:) name:@"AwokeFromUserIdle" object:nil];
    
    //set up audio notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioVolumeDidChange:) name:@"audioVolumeChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(soundDidChange:) name:@"soundChanged" object:nil];
    
    //Misc Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applescriptAppNotInFolder:) name:@"applescriptAppicationNotInFolder" object:nil];
    
//    //Go Sphero!
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRobotOnline) name:RKDeviceConnectionOnlineNotification object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(handleRobotOffline)
//                                                 name:RKRobotIsNoLongerAvailableNotification
//                                               object:nil];
    
    //then set up defaults
    [self setDefaults];
}

#pragma mark - Hot Key Methods

- (SGHotKey *)hotKeyWithKey:(NSString *)keyString withSelector:(SEL)selectorStuffs
{
    //get a plist from the user defaults
    id keyComboPlist = [[NSUserDefaults standardUserDefaults] objectForKey:keyString];
    
    //the keyCombo represents a single keyCombo
    SGKeyCombo *keyCombo = [[SGKeyCombo alloc] initWithPlistRepresentation:keyComboPlist];

    //create a hotkey for the hotkey identifier used to get the plist, set up an action
    SGHotKey *h = [[SGHotKey alloc] initWithIdentifier:keyString keyCombo:keyCombo target:self action:selectorStuffs];

    //register the hotkey
    [[SGHotKeyCenter sharedCenter] registerHotKey:h];
    
    return h;
}

- (void)stopPomodoroKeyed:(id)sender;
{
    EggTimer *currentTimer = [EggTimer currentTimer];
    if( currentTimer && currentTimer.status == TimerStatusRunning )
    {
        [currentTimer stop];
    }
}

- (void)externalInterruptionKeyed:(id)sender;
{
    int modifier = (sender == nil) ? -1 : 1;
    Activity *a = [Activity currentActivity];
    Egg *p = [[a.eggs allObjects] lastObject];
    
    int intValue = MAX([p.externalInterruptions intValue] + modifier, 0);
    intValue = MIN(intValue, 99);
    p.externalInterruptions = [NSNumber numberWithInt:intValue];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"externalInterruptionKeyed" object:nil];
    
    EggTimer *currentTimer = [EggTimer currentTimer];
    [currentTimer pause];
}

- (void)internalInterruptionKeyed:(id)sender;
{
    int modifier = (sender == nil) ? -1 : 1;
    Activity *a = [Activity currentActivity];
    Egg *p = [[a.eggs allObjects] lastObject];
    
    int intValue = MAX([p.internalInterruptions intValue] + modifier, 0);
    intValue = MIN(intValue, 99);
    p.internalInterruptions = [NSNumber numberWithInt:intValue];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"internalInterruptionKeyed" object:nil];
    
    EggTimer *currentTimer = [EggTimer currentTimer];
    [currentTimer pause];
}

- (void)toggleHoverWindowKeyed:(id)sender;
{
    if(monitorWindowController.window.isVisible)
    {
        [monitorWindowController.window close];
    }
    else
    {
        [monitorWindowController.window makeKeyAndOrderFront:nil];
    }
}

- (void)togglePomodoroKeyed:(id)sender;
{
    
}

- (void)toggleNoteKeyed:(id)sender;
{
    if(!historyWindowController)
        historyWindowController = [[HistoryWindowController alloc] initWithWindowNibName:@"HistoryWindowController"];
    
    if([historyWindowController.window isVisible])
    {
        [historyWindowController close:self];
    }
    else
    {
        [historyWindowController showWindow:self];
        [historyWindowController.window makeKeyAndOrderFront:self];
        [NSApp activateIgnoringOtherApps:YES];
    }
}

#pragma mark - Idle check based methods

- (void)idleHeartbeat
{
    int idleTimeThreshold = 600;
    BOOL consideredIdle = lastRecordedIdleTime >= idleTimeThreshold;
    int currentIdleTime = (int)[idleTime secondsIdle];
    
    if(consideredIdle && currentIdleTime < idleTimeThreshold)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AwokeFromUserIdle" object:nil];
    }
    lastRecordedIdleTime = currentIdleTime;
}

- (void)pullAndStartPomodoro
{
    //TODO: please implement
    Activity *a = [Activity currentActivity];
    if(a)
    {
        EggTimer *pomo = [a crackAnEgg];
        [pomo startAfterDelay:EGG_REQUEST_DELAY];
    }
    else 
    {
        [panelController openPanel];
    }
}

//#pragma mark - Sphero Integration
//
//- (void)handleRobotOnline
//{
//    [RKRGBLEDOutputCommand sendCommandWithRed:0.5 green:0.5 blue:0.0];
//    
//    ////First turn off stabilization so the drive mechanism does not move.
//    [RKStabilizationCommand sendCommandWithState:RKStabilizationStateOff];
//    
//    ////Register for asynchronise data streaming packets
//    [[RKDeviceMessenger sharedMessenger] addDataStreamingObserver:self selector:@selector(handleAsyncData:)];
//    
//    //start streaming
//    //[self beginStreaming];
//    robotOnline = YES;
//}
//
//- (void)handleRobotOffline
//{
//    robotOnline = NO;
//}
//
//- (void) beginStreaming
//{
//    //// Start data streaming for the accelerometer and IMU data. The update rate is set to 20Hz with
//    //// one sample per update, so the sample rate is 10Hz. Packets are sent continuosly.
//    [RKSetDataStreamingCommand sendCommandWithSampleRateDivisor:100 packetFrames:1
//                                                     sensorMask:RKDataStreamingMaskAccelerometerXFiltered |
//     RKDataStreamingMaskAccelerometerYFiltered |
//     RKDataStreamingMaskAccelerometerZFiltered |
//     RKDataStreamingMaskIMUPitchAngleFiltered |
//     RKDataStreamingMaskIMURollAngleFiltered |
//     RKDataStreamingMaskIMUYawAngleFiltered
//                                                    packetCount:20];
//    updatePacketsLeft = 10;
//}
//
//- (void) endStreaming
//{
//    /*When the application is entering the background we need to close the connection to the robot*/
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:RKDeviceConnectionOnlineNotification object:nil];
//    
//    // Turn off data streaming
//    [RKSetDataStreamingCommand sendCommandWithSampleRateDivisor:0
//                                                   packetFrames:0
//                                                     sensorMask:RKDataStreamingMaskOff
//                                                    packetCount:0];
//    // Unregister for async data packets
//    [[RKDeviceMessenger sharedMessenger] removeDataStreamingObserver:self];
//    
//    // Restore stabilization (the control unit)
//    [RKStabilizationCommand sendCommandWithState:RKStabilizationStateOn];
//    
//    // Close the connection
//    [[RKRobotProvider sharedRobotProvider] closeRobotConnection];
//}
//
//- (void)handleAsyncData:(RKDeviceAsyncData *)asyncData
//{
//    // Need to check which type of async data is received as this method will be called for
//    // data streaming packets and sleep notification packets. We are going to ingnore the sleep
//    // notifications.
//    if ([asyncData isKindOfClass:[RKDeviceSensorsAsyncData class]])
//    {
//        // Received sensor data, so display it to the user.
//        RKDeviceSensorsAsyncData *sensorsAsyncData = (RKDeviceSensorsAsyncData *)asyncData;
//        RKDeviceSensorsData *sensorsData = [sensorsAsyncData.dataFrames lastObject];
//        RKAccelerometerData *accelerometerData = sensorsData.accelerometerData;
//        RKAttitudeData *attitudeData = sensorsData.attitudeData;
//        
//        NSLog(@"attitudeData yaw: %.6f", attitudeData.yaw, nil);
//       // NSLog(@"accelerometer y: %.6f", accelerometerData.acceleration.y, nil);
//        
////        latestSpheroSensorData.accelX = accelerometerData.acceleration.x;
////        latestSpheroSensorData.accelY = accelerometerData.acceleration.y;
////        latestSpheroSensorData.accelZ = accelerometerData.acceleration.z;
////        
////        latestSpheroSensorData.pitch = attitudeData.pitch;
////        latestSpheroSensorData.roll = attitudeData.roll;
////        latestSpheroSensorData.yaw = attitudeData.yaw;
//        
//        updatePacketsLeft--;
//        if (updatePacketsLeft == 0)
//        {
//            [self beginStreaming];
//        }
//        
//    }
//}

#pragma mark - Defaults

- (void)setDefaults
{
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"firstRunComplete"])
    {
        NSString *f = [[NSBundle mainBundle] pathForResource:@"initialDefaults" ofType:@"plist"];
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:f];        
        
        for(NSString *s in d.allKeys)
        {
            [[NSUserDefaults standardUserDefaults] setValue:[d valueForKey:s] forKey:s];
        }
        
        Activity *a = [Activity activity];
        a.name = NSLocalizedString(@"Open Eggscellent for the first time", @"Open Eggscellent for the first time");
        a.completed = [NSDate date];
        a.plannedCount = [NSNumber numberWithInt:1];
        
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"firstRunComplete"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[ModelStore sharedStore] save];
    }
    
    self.hotKeyExternalInterrupt = [self hotKeyWithKey:HOTKEY_EXTERNAL_INTERRUPTION withSelector:@selector(externalInterruptionKeyed:)];
    self.hotKeyInternalInterrupt = [self hotKeyWithKey:HOTKEY_INTERNAL_INTERRUPTION withSelector:@selector(internalInterruptionKeyed:)];
    self.hotKeyStopPomodoro = [self hotKeyWithKey:HOTKEY_STOP_POMODORO withSelector:@selector(stopPomodoroKeyed:)];
    self.hotKeyToggleStatusItemWindow = [self hotKeyWithKey:HOTKEY_TOGGLE_STATUSITEM_WINDOW withSelector:@selector(togglePanel:)];
    self.hotKeyToggleHoverWindow = [self hotKeyWithKey:HOTKEY_TOGGLE_HOVER_WINDOW withSelector:@selector(toggleHoverWindowKeyed:)];
    self.hotKeyToggleNoteWindow = [self hotKeyWithKey:HOTKEY_TOGGLE_NOTE_WINDOW withSelector:@selector(toggleNoteKeyed:)];
}

- (BOOL)startAtLogin
{
    NSDictionary *dict = (NSDictionary*)CFBridgingRelease(SMJobCopyDictionary(kSMDomainUserLaunchd, 
                                                            CFSTR("com.monoclesociety.eggscellent.osx")));
    BOOL contains = (dict!=NULL);
    return contains;
}

- (BOOL)isStartedAtLogin
{
    
    BOOL isEnabled  = NO;

    // the easy and sane method (SMJobCopyDictionary) can pose problems when sandboxed. -_-
    CFArrayRef cfJobDicts = SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
    NSArray* jobDicts = CFBridgingRelease(cfJobDicts);
    NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
    if (jobDicts && [jobDicts count] > 0) {
        for (NSDictionary* job in jobDicts) {
            if ([bundleIdentifier isEqualToString:[job objectForKey:@"Label"]])
            {
                isEnabled = [[job objectForKey:@"OnDemand"] boolValue];
                break;
            }
        }
    }
    
    return isEnabled;
}

- (void)updateLoginItem:(BOOL)loginItem
{  
    bool login = loginItem ? true : false;

    NSString *bundleIdentifier = @"com.monoclesociety.eggscellent.osx.helper";

    if (!SMLoginItemSetEnabled((__bridge CFStringRef)bundleIdentifier, login))
    {
        NSLog(@"ERROR: Eggscellent failed to toggle auto login");
    }
    [[NSUserDefaults standardUserDefaults] setBool:loginItem forKey:@"autoLogin"];
}

#pragma mark - NSNotifications

- (void)PomodoroRequested:(NSNotification *)note
{
    [self setupSounds];
}

- (void)PomodoroTimeStarted:(NSNotification *)note
{
    EggTimer *pomo = (EggTimer *)[note object];
    if(pomo.type == TimerTypeEgg)
    {
        [statusItem setLength:STATUS_ITEM_VIEW_EGG_WIDTH];
        BOOL playSound = [[NSUserDefaults standardUserDefaults] boolForKey:@"playTickSound"];
        if(playSound)
            [self.tickSound play];
    }
    
//    if(robotOnline)
//        [RKRGBLEDOutputCommand sendCommandWithRed:0.5 green:0.5 blue:0.0];
}

- (void)PomodoroClockTicked:(NSNotification *)note
{
    EggTimer *pomo = (EggTimer *)[note object];
    int diff = pomo.timeEstimated - pomo.timeElapsed;
    int minutesLeft = diff / 60;
    int secondsleft = diff % 60;

    if(pomo.type == TimerTypeEgg)
    {
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"playTickSound"] && ![self.tickSound isPlaying] && pomo.status != TimerStatusPaused)
        {
            [self.tickSound play];
        }
        else if(![[NSUserDefaults standardUserDefaults] boolForKey:@"playTickSound"] && [tickSound isPlaying])
        {
            [self.tickSound stop];
        }
        else if ([[NSUserDefaults standardUserDefaults] boolForKey:kPlayAttentionCheckSound])
        {
            if (secondsleft == 0 && (minutesLeft == 20 || minutesLeft == 10))
            {
                [self.clockSound play];
            }
            else if (secondsleft == 0 && (minutesLeft == 15 || minutesLeft == 5))
            {
                [self.gongSound play];
            }
        }
    }
    
    NSString *stringFormat = @"%02d:%02d";
    statusView.timerString = [NSString stringWithFormat:stringFormat, minutesLeft, secondsleft, nil];
    
    [statusView setNeedsDisplay:YES];
}

- (void)PomodoroTimeCompleted:(NSNotification *)note
{
    EggTimer *egg = [note object];
    [self.tickSound stop];    
    
    if(egg.type == TimerTypeEgg)
    {
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"playCompleteSound"])
            [self.pomodoroCompleteSound play];
        
        if(NSClassFromString(@"NSUserNotification"))
        {
            NSUserNotification *userNotification = [[NSUserNotification alloc] init];
            userNotification.title = NSLocalizedString(@"Timer Completed", @"Timer Completed");
            userNotification.subtitle = [Activity currentActivity].name;
            [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:userNotification];
        }

        Egg *e = [Egg lastEgg];
        
        e.timeElapsed = [NSNumber numberWithInt:egg.timeElapsed];
        e.timeEstimated = [NSNumber numberWithInt:egg.timeEstimated];
        e.outcome = [NSNumber numberWithInt:EggOutcomeCompleted];
        e.activity = [Activity currentActivity];
        
        //Calendar integration support
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"calendarIntegrationEnabled"])
            [calendarController createCalendarLogForEgg:e];
        
        //if you just met the requirements for auto-complete, then auto-complete!
        Activity *a = [Activity currentActivity];
        
        if([a.completedEggs count] == [a.plannedCount intValue] && [[NSUserDefaults standardUserDefaults] boolForKey:@"autoCompleteTasks"])
            a.completed = [NSDate date];
            
        [a save];
        [a refresh];
        
        TimerType timerType = TimerTypeShortBreak;
        
        //checking that we don't loop past 4, plus for that crappy bug
        int breakCounterTimeStamp = [breakCounterDate timeIntervalSince1970];
        int currentTimeStamp = [[NSDate date] timeIntervalSince1970];
        int timeStampDiff = currentTimeStamp - breakCounterTimeStamp;
        if(breakCounter == 3 && timeStampDiff < 14400)
        {
            timerType = TimerTypeLongBreak;
            breakCounter = 0;
        }
        
        EggTimer *p = [[EggTimer alloc] initWithType:timerType];
        [EggTimer setCurrentTimer:p];
        [p start];
        
        breakCounterDate = [NSDate date];
        breakCounter++;
        
//        if(robotOnline)
//            [RKRGBLEDOutputCommand sendCommandWithRed:0.5 green:0.5 blue:0.5];
        
        return;
    }
    
    if(egg.type == TimerTypeLongBreak || egg.type == TimerTypeShortBreak)
    {
        if(NSClassFromString(@"NSUserNotification"))
        {
            NSUserNotification *userNotification = [[NSUserNotification alloc] init];
            userNotification.title = NSLocalizedString(@"Break Completed", @"Break Completed");
            userNotification.subtitle = [Activity currentActivity].name;
            [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:userNotification];
        }
        
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"playBreakCompleteSound"])
            [self.breakCompleteSound play];
        
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"autoStartNextTimer"])
        {
            Activity *a = [Activity currentActivity];
            EggTimer *e = [a crackAnEgg];
            [e startAfterDelay:EGG_REQUEST_DELAY];
        }
        else
        {
            [statusItem setLength:STATUS_ITEM_VIEW_DEFAULT_WIDTH];
            statusView.timerString = @"";
            [statusView setNeedsDisplay:YES];
        }
    }
}

- (void)PomodoroStopped:(NSNotification *)note
{
    [self.tickSound stop];
    [statusItem setLength:STATUS_ITEM_VIEW_DEFAULT_WIDTH];
    statusView.timerString = @"";
    [statusView setNeedsDisplay:YES];
    
    EggTimer *pomo = [note object];
    if(pomo.type == TimerTypeEgg)
    {
#ifdef __MAC_10_8
        NSUserNotification *userNotification = [[NSUserNotification alloc] init];
        userNotification.title = @"Timer Stopped.";
        userNotification.subtitle = [Activity currentActivity].name;
        [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:userNotification];
#endif
    }
    
//    if(robotOnline)
//        [RKRGBLEDOutputCommand sendCommandWithRed:0.5 green:0.0 blue:0.0];
    
    [[Activity currentActivity] save];
}

- (void)pomodoroPaused:(NSNotification *)note
{
    [self.tickSound stop];
}

- (void)pomodoroResume:(NSNotificationCenter *)note
{
    [self.tickSound play];
}

- (void)ActivityModifiedCompletion:(NSNotification *)note
{
    [taskSyncController syncActivity:[note object]];
}

- (void)awokeFromIdle:(NSNotification *)note
{
    EggTimer *pomo = [EggTimer currentTimer];

    if(pomo.status != TimerStatusRunning)
    {
        if(!idleAlert)
        {
            idleAlert = [[NSAlert alloc] init];
            [idleAlert addButtonWithTitle:@"Yes Please"];
            [idleAlert addButtonWithTitle:@"No Thanks"];
            [idleAlert setMessageText:@"Welcome Back!"];
            [idleAlert setInformativeText:@"Would you like to start work on another task?"];
            [idleAlert setShowsSuppressionButton:YES];
            [idleAlert setAlertStyle:NSInformationalAlertStyle];
        }
        switch ([[NSUserDefaults standardUserDefaults] integerForKey:@"idleNudgePreference"]) 
        {
            case 0:
                break;
            case 1:
                [self pullAndStartPomodoro];
                break;
            case 2:
                [idleAlert beginSheetModalForWindow:nil modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
                break;
        }
    }
}

- (void)audioVolumeDidChange:(NSNotification *)note
{
    NSNumber *ov = (NSNumber *)[note object];
    
    float v = [ov floatValue];
    float x = 100.0f;
    float f = v / x;
    
    [self.breakCompleteSound setVolume:f];
    [self.tickSound setVolume:f];
    [self.pomodoroCompleteSound setVolume:f];
    [self.clockSound setVolume:f];
    [self.tickSound setVolume:f];
}

- (void)soundDidChange:(NSNotification *)note
{
    NSString *prefKey = [note object];
    if([prefKey isEqualToString:@"tickAudioPath"])
    {
        [self.tickSound stop];
        self.tickSound = [AVAudioPlayer soundForPreferenceKey:prefKey];
        self.tickSound.numberOfLoops = 1e100;
    }
    else if([prefKey isEqualToString:@"timerCompleteAudioPath"])
    {
        [self.pomodoroCompleteSound stop];
        self.pomodoroCompleteSound = [AVAudioPlayer soundForPreferenceKey:prefKey];
    }
    else if([prefKey isEqualToString:@"breakAudioPath"])
    {
        [self.breakCompleteSound stop];
        self.breakCompleteSound = [AVAudioPlayer soundForPreferenceKey:prefKey];
    }
}

- (void)taskManagerTypeChanged:(NSNotification *)note
{
    [self setupTaskSyncing];
}

- (void)applescriptAppNotInFolder:(NSNotification *)note
{
    NSString *appName = (NSString *)[note object];
    
    if(!errorAlert)
    {
        errorAlert = [[NSAlert alloc] init];
        [errorAlert addButtonWithTitle:@"OK"];
        [errorAlert setAlertStyle:NSInformationalAlertStyle];
    }
    
    //Title text
    NSString *titleText = [NSString stringWithFormat:@"%@ integration could not be completed", appName, nil];
    [errorAlert setMessageText:titleText];
    
    //Informative text
    NSString *informativeText = [NSString stringWithFormat:@"Eggscellent has detected that while %@ is running, it may not be in your main Applications folder.\n\nPlease quit or move %@ to the Applications folder to continue", appName, appName, nil];
    [errorAlert setInformativeText:informativeText];
    
    [errorAlert runModal];
}

#pragma mark - NSAlert Delegate method

- (void) alertDidEnd:(NSAlert *) alert returnCode:(int) returnCode contextInfo:(int *) contextInfo
{
    if(returnCode == 1000) //Yes Please
    {
        [panelController openPanel];
    }
    
    if([[alert suppressionButton] state] == NSOnState)
    {
        [[NSUserDefaults standardUserDefaults] setValue:0 forKey:@"idleNudgePreference"];
        [[alert suppressionButton] setState:NSOffState];
    }
}

#pragma mark - Actions

- (IBAction)togglePanel:(id)sender
{
    [taskSyncController sync];
    
    if(self.panelController.isOpen)
        [self.panelController closePanel];
    else
        [self.panelController openPanel];
}

#pragma mark - Welcome based methods

- (void)displayWelcome
{
    welcomeWindowController = [[WelcomeWindowController alloc] initWithWindowNibName:@"WelcomeWindowController"];
    [welcomeWindowController showWindow:nil];
    [welcomeWindowController.window makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - Helper Methods

- (void)setupTaskSyncing
{
    taskSyncController = nil;
    
    int taskType = [[[NSUserDefaults standardUserDefaults] valueForKey:@"taskManagerType"] intValue];
    switch(taskType)
    {
        case ActivitySourceNone:
            taskSyncController = nil;
            break;
        case ActivitySourceReminders:
            taskSyncController = [[RemindersSyncController alloc] init];
            break;
        case ActivitySourceOmniFocus:
            taskSyncController = [[OmniFocusSyncController alloc] init];
            break;
        case ActivitySourceThings:
            taskSyncController = [[ThingsSyncController alloc] init];
            break;
    }
    
    [TaskSyncController setCurrentController:taskSyncController];
    
    [taskSyncController sync];
}

- (void)setupSounds
{
    self.clockSound = [AVAudioPlayer soundForFilename:@"clock.m4a"];
    self.gongSound = [AVAudioPlayer soundForFilename:@"gong.m4a"];
    
    self.tickSound = [AVAudioPlayer soundForPreferenceKey:@"tickAudioPath"];
    self.tickSound.numberOfLoops = 1e100;
    
    self.pomodoroCompleteSound = [AVAudioPlayer soundForPreferenceKey:@"timerCompleteAudioPath"];    
    self.breakCompleteSound = [AVAudioPlayer soundForPreferenceKey:@"breakAudioPath"];
}

- (void)loadHelperWindow:(BOOL)shouldLoad withNormalSize:(BOOL)normalSize;
{
    if(!monitorWindowController)
    {
        monitorWindowController = [[MonitorWindowController alloc] init];
    }
    
    if(shouldLoad)
    {
        EggTimer *currentTimer = [EggTimer currentTimer];
        if(currentTimer && currentTimer.status == TimerStatusRunning)
            [monitorWindowController.window makeKeyAndOrderFront:nil];
    }
    else
    {
        [monitorWindowController close];
    }
}

- (WindowController *)windowController
{
    if(windowController == nil)
    {
        windowController = [[WindowController alloc] initWithWindowNibName:@"WindowController"];
    }
    return windowController;
}

- (PanelController *)panelController
{
    if (panelController == nil)
    {
        panelController = [[PanelController alloc] initWithDelegate:self];
    }
    return panelController;
}

#pragma mark - PanelControllerDelegate

- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller
{
    return statusView;
}

- (StatusItemView *)statusItemView;
{
    return statusView;
}

- (void)openPreferences;
{
    if (!preferencesWindow)
    {
        ShortcutsPreferencesViewController *shortcutsViewController = [[ShortcutsPreferencesViewController alloc] initWithNibName:@"ShortcutsPreferencesViewController" bundle:nil];
        NotificationsPreferencesViewController *notificationsViewController = [[NotificationsPreferencesViewController alloc] initWithNibName:@"NotificationsPreferencesViewController" bundle:nil];
        IntegrationPreferencesViewController *integrationViewController = [[IntegrationPreferencesViewController alloc] initWithNibName:@"IntegrationPreferencesViewController" bundle:nil];
        GeneralPreferencesViewController *generalViewController = [[GeneralPreferencesViewController alloc] init];
        //DevicesPreferencesViewController *devicesViewController = [[DevicesPreferencesViewController alloc] init];
        
        shortcutsViewController.hotKeyToggleStatusItemWindow = self.hotKeyToggleStatusItemWindow;
        shortcutsViewController.hotKeyStopPomodoro = self.hotKeyStopPomodoro;
        shortcutsViewController.hotKeyInternalInterrupt = self.hotKeyInternalInterrupt;
        shortcutsViewController.hotKeyExternalInterrupt = self.hotKeyExternalInterrupt;
        shortcutsViewController.hotKeyToggleHoverWindow = self.hotKeyToggleHoverWindow;
        shortcutsViewController.hotKeyToggleNoteWindow = self.hotKeyToggleNoteWindow;
        
        NSMutableArray *controllers = [[NSMutableArray alloc] initWithObjects:generalViewController, shortcutsViewController, notificationsViewController, integrationViewController, nil];
        
        if(NSClassFromString(@"NSUserNotification"))
        {
            CalendarPreferencesViewController *calendarViewController = [[CalendarPreferencesViewController alloc] initWithNibName:@"CalendarPreferencesViewController" bundle:nil];
            calendarViewController.calendarController = calendarController;
            [controllers addObject:calendarViewController];
        }
        
        NSString *title = NSLocalizedString(@"Eggscellent Preferences", @"Common title for Preferences window");
        preferencesWindow = [[MASPreferencesWindowController alloc] initWithViewControllers:controllers title:title];
    }
    
    [NSApp activateIgnoringOtherApps:YES];
    [preferencesWindow showWindow:self];
}

@end