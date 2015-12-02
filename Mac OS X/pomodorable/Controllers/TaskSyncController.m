//
//  TaskSyncController.m
//  pomodorable
//
//  Created by Kyle Kinkade on 11/23/11.
//  Copyright (c) 2011 Monocle Society LLC All rights reserved.
//

#import "TaskSyncController.h"

NSString * const kPlannedCountKey = @"kPlannedCountKey";

@implementation TaskSyncController
@synthesize importedIDs;

#pragma mark - Class based methods

static TaskSyncController *singleton;
+ (TaskSyncController *)currentController;
{
    return singleton;
}

+ (void)setCurrentController:(TaskSyncController *)controller;
{
    singleton = controller;
}

#pragma mark - General methods
        
- (id)init
{
    self = [super init];
    if (self)
    {
        self.importedIDs = nil;
        syncCount = 0;
        currentCount = 0;

        self.pmoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        self.pmoc.parentContext = [ModelStore sharedStore].managedObjectContext;
        
        queue = dispatch_queue_create("com.monoclesociety.eggscellent.sync", NULL);
    }
    return self;
}

- (BOOL)sync
{
    return YES;
}

- (void)cleanUpSync
{
    
}

- (void)dealloc
{
    [[ModelStore sharedStore] save];
}

- (void)syncActivity:(Activity *)activity
{

}

- (void)saveNewActivity:(Activity *)activity;
{
    
}

#pragma mark - helper methods

- (void)prepare
{
    self.importedIDs = [NSMutableDictionary dictionary];
    tasksChanged = NO;
    currentCount = 0;
    syncCount = 0;
}

- (void)completeActivities;
{
    [self.pmoc performBlockAndWait:^{
        
        NSError *error;
        NSFetchRequest *fetchRequest = [[ModelStore sharedStore] fetchRequestForFilteredActivities];
        NSArray *results = [self.pmoc executeFetchRequest:fetchRequest error:&error];
        
        for(Activity *a in results)
        {
            int sourceInt = [a.source intValue];
            if(sourceInt == source)
            {
                if(![importedIDs valueForKey:a.sourceID] && (!a.completed))
                {
                    [a secretSetRemoved:[NSNumber numberWithBool:YES]];
                }
            }
            else
            {
                //if this is NOT from the source BUT it is completed, we leave
                //it alone, otherwise, it goes away.
                [a secretSetRemoved:[NSNumber numberWithBool:(!a.completed)]];
            }
        }
        
        error = nil;
        
        [self.pmoc save:&error];

        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[ModelStore sharedStore] save];
            
            if(tasksChanged)
                [[NSNotificationCenter defaultCenter] postNotificationName:SYNC_COMPLETED_WITH_CHANGES object:self];
            
            self.importedIDs = nil;
            currentCount = 0;
            syncCount = 0;
            
        });
    }];
}

- (void)syncWithDictionary:(NSDictionary *)dictionary
{
    [self.pmoc performBlock:^{
        
        NSError *err = nil;
        NSNumber *status = [dictionary objectForKey:@"status"];
        NSString *ID = [dictionary objectForKey:@"ID"];
        NSString *name = [dictionary objectForKey:@"name"];
        NSString *details = [dictionary objectForKey:@"details"];
        NSNumber *plannedCount = [dictionary objectForKey:kPlannedCountKey];
        plannedCount = @(MAX(1, [plannedCount integerValue]));
        
        //check for
        NSFetchRequest *fetchRequest = [[ModelStore sharedStore] activityExistsForSourceID:ID];
        NSUInteger count = [self.pmoc countForFetchRequest:fetchRequest error:&err];
        
        if(!count)
        {
            Activity *newActivity = [NSEntityDescription insertNewObjectForEntityForName:@"Activity"
                                                                  inManagedObjectContext:self.pmoc];
            newActivity.source = [NSNumber numberWithInteger:source];
            newActivity.name = name;
            newActivity.details = details;
            newActivity.sourceID = ID;
            newActivity.plannedCount = plannedCount;
            [newActivity secretSetCompleted:[status boolValue] ? [NSDate date] : nil];
        
            tasksChanged = YES;
        }
        else
        {
            NSError *error;
            
            // Create the fetch request for the entity.
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            
            // Edit the entity name as appropriate.
            NSEntityDescription *entity = [NSEntityDescription entityForName:@"Activity" inManagedObjectContext:self.pmoc];
            
            //set up the fetchRequest
            [fetchRequest setEntity:entity];
            [fetchRequest setIncludesSubentities:NO];
            [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"sourceID == %@", ID, nil]];

            NSArray *results = [self.pmoc executeFetchRequest:fetchRequest error:&error];
            Activity *existingActivity = [results objectAtIndex:0];
            
            
            NSString *munge = [NSString stringWithFormat:@"%@%@%@", existingActivity.name,
                               [existingActivity.removed stringValue],
                               [existingActivity.completed description],
                               nil];
            
            existingActivity.name = name;
            existingActivity.details = details;
            existingActivity.plannedCount = @(MAX([existingActivity.plannedCount integerValue], [plannedCount integerValue]));
            [existingActivity secretSetRemoved:[NSNumber numberWithBool:NO]];
            
            BOOL completedBool = (existingActivity.completed);
            BOOL statusBool = [status boolValue];
            
            if(completedBool != statusBool)
                [existingActivity secretSetCompleted:[status boolValue] ? [NSDate date] : nil];

            NSString *alter  = [NSString stringWithFormat:@"%@%@%@", existingActivity.name,
                                [existingActivity.removed stringValue],
                                [existingActivity.completed description],
                                nil];
            
            BOOL different = ![munge isEqualToString:alter];
            if(different)
                tasksChanged = YES;
        }
        
        [importedIDs setValue:ID forKey:ID];
        
        
        
        currentCount++;
        if(currentCount == syncCount)
        {
            [self completeActivities];
        }
    }];
}

@end