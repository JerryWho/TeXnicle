//
//  TPLibrary.m
//  TeXnicle
//
//  Created by Martin Hewitson on 15/7/12.
//  Copyright (c) 2012 bobsoft. All rights reserved.
//

#import "TPLibrary.h"

NSString * const TPLibraryDidUpdateNotification = @"TPLibraryDidUpdateNotification";


@implementation TPLibrary

@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize managedObjectContext = __managedObjectContext;

- (id) init
{
  self = [super init];
  if (self) {
    [self setupLibrary];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(applicationWillTerminate:) 
               name:NSApplicationWillTerminateNotification
             object:[NSApplication sharedApplication]];
  }
  return self;
}

- (void) applicationWillTerminate:(NSNotification*)aNote
{
  [self saveAction:self];
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [__persistentStoreCoordinator release];
  [__managedObjectModel release];
  [__managedObjectContext release];
  [super dealloc];
}

- (void) updateSortIndices
{
  NSInteger categoryIndex = 0;
	for (TPLibraryCategory *category in [self categories]) {
    
    // get category with this name, or make one
    category.sortIndex = [NSNumber numberWithInteger:categoryIndex];
    
    NSInteger entryIndex = 0;
		for (TPLibraryEntry *entry in [self entriesForCategory:category]) {      
      entry.sortIndex = [NSNumber numberWithInteger:entryIndex];
      entryIndex++;
    }
    categoryIndex++;
  }
  
}

#pragma mark -
#pragma mark Core Data


// Returns the directory the application uses to store the Core Data store file. This code uses a directory named "com.bobsoft.TestCoreDataProperties" in the user's Application Support directory.
- (NSURL *)applicationFilesDirectory
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
  return [appSupportURL URLByAppendingPathComponent:@"TeXnicle"];
}

// Creates if necessary and returns the managed object model for the application.
- (NSManagedObjectModel *)managedObjectModel
{
  if (__managedObjectModel) {
    return __managedObjectModel;
  }
	
  NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"library" withExtension:@"momd"];
  __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
  return __managedObjectModel;
}

// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
  if (__persistentStoreCoordinator) {
    return __persistentStoreCoordinator;
  }
  
  NSManagedObjectModel *mom = [self managedObjectModel];
  if (!mom) {
    NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
    return nil;
  }
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
  NSError *error = nil;
  
  NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] error:&error];
  
  if (!properties) {
    BOOL ok = NO;
    if ([error code] == NSFileReadNoSuchFileError) {
      ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
    }
    if (!ok) {
      [[NSApplication sharedApplication] presentError:error];
      return nil;
    }
  } else {
    if (![[properties objectForKey:NSURLIsDirectoryKey] boolValue]) {
      // Customize and localize this error.
      NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
      
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
      error = [NSError errorWithDomain:@"TeXnicle_Error" code:101 userInfo:dict];
      
      [[NSApplication sharedApplication] presentError:error];
      return nil;
    }
  }
  
  NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"library.storedata"];
  NSMutableDictionary *options = nil;
  [options setObject:[NSNumber numberWithBool:YES] 
							forKey:NSMigratePersistentStoresAutomaticallyOption];
  NSPersistentStoreCoordinator *coordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom] autorelease];
  if (![coordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:options error:&error]) {
    [[NSApplication sharedApplication] presentError:error];
    return nil;
  }
  __persistentStoreCoordinator = [coordinator retain];
  
  return __persistentStoreCoordinator;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) 
- (NSManagedObjectContext *)managedObjectContext
{
  if (__managedObjectContext) {
    return __managedObjectContext;
  }
  
  NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
  if (!coordinator) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
    [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
    NSError *error = [NSError errorWithDomain:@"TeXnicle_Error" code:9999 userInfo:dict];
    [[NSApplication sharedApplication] presentError:error];
    return nil;
  }
  __managedObjectContext = [[NSManagedObjectContext alloc] init];
  [__managedObjectContext setPersistentStoreCoordinator:coordinator];
  
  [__managedObjectContext setUndoManager:[[NSApplication sharedApplication] undoManager]];
  
  return __managedObjectContext;
}


// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
- (IBAction)saveAction:(id)sender
{
  NSError *error = nil;
  
  if (![[self managedObjectContext] commitEditing]) {
    NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
  }
  
  if (![[self managedObjectContext] save:&error]) {
    [[NSApplication sharedApplication] presentError:error];
  }
}



#pragma mark -
#pragma mark Library Management


- (void) setupLibrary
{
  // first we check to see if we already have a library
  NSArray *categories = [self categories];
  if (categories != nil && [categories count] > 0) {
    return;
  }
  
  // load the default library
  NSMutableDictionary *defaultLibrary = [self loadDefaultLibrary];
  
  // if we have an old plist style library in user defaults, migrate it and remove it from the defaults
  NSMutableDictionary *oldLibrary = [self getOldLibraryWithDefaultCategories:defaultLibrary];
  if (oldLibrary != nil) {
    // migrate it
    [self migrateOldPlistLibrary:oldLibrary];
    
    // remove from user defaults
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Library"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
  } else {
    [self migrateOldPlistLibrary:defaultLibrary];
  }
  
  [self saveAction:self];
}

- (NSMutableDictionary*)loadDefaultLibrary
{
	NSString *libpath = [[NSBundle mainBundle] pathForResource:@"Library" ofType:@"plist"];
	return [NSMutableDictionary dictionaryWithContentsOfFile:libpath];
}

- (NSMutableDictionary*)getOldLibraryWithDefaultCategories:(NSMutableDictionary*)defaultLibrary
{
	NSMutableArray *categories = [self categorySetFromDefaults:defaultLibrary];	
  if (categories != nil) {
    NSMutableDictionary *library = [[NSMutableDictionary alloc] init];
    [library setObject:categories forKey:@"Categories"];
    return [library autorelease];
  }
  return nil;
}

- (void) migrateOldPlistLibrary:(NSMutableDictionary*)libraryIn
{
  NSInteger categoryCount = 0;
	for (NSDictionary *category in [libraryIn valueForKey:@"Categories"]) {
    
    NSString *categoryName = [category valueForKey:@"Name"];
    
    // get category with this name, or make one
    TPLibraryCategory *newCategory = [self getOrCreateCategoryWithName:categoryName];
    newCategory.sortIndex = [NSNumber numberWithInteger:categoryCount];
    
    NSInteger entryCount = 0;
		for (NSMutableDictionary *clip in [category valueForKey:@"Contents"]) {
      
      TPLibraryEntry *entry =[TPLibraryEntry entryWithDictionary:clip
                                                      inCategory:newCategory
                                          inManagedObjectContext:self.managedObjectContext];
      
      if (entry.uuid == nil || [entry.uuid length] == 0) {
        entry.uuid = [NSString stringWithUUID];
      }
      entry.sortIndex = [NSNumber numberWithInteger:entryCount];
      entryCount++;
    }
    
    categoryCount++;
  }
  
  [self.managedObjectContext processPendingChanges];
}

- (NSMutableArray*)categorySetFromDefaults:(NSMutableDictionary*)defaultLibrary
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  // read library
	NSDictionary *libraryIn = [defaults valueForKey:@"Library"];  
  if (libraryIn == nil) {
    return nil;
  }
  
	NSMutableArray *categories = [[NSMutableArray alloc] init];
	
	// check all images
	for (NSDictionary *category in [libraryIn valueForKey:@"Categories"]) {
		NSMutableDictionary *newCategory = [[NSMutableDictionary alloc] init];
		[newCategory setValue:[category valueForKey:@"Name"] forKey:@"Name"];		
		NSMutableArray *clips = [NSMutableArray array];		
		for (NSMutableDictionary *clip in [category valueForKey:@"Contents"]) {
			
			NSMutableDictionary *newClip = [[NSMutableDictionary alloc] initWithDictionary:clip];
			[newClip setValue:[[clip valueForKey:@"Code"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] 
								 forKey:@"Code"];
      
      [newClip setValue:[clip valueForKey:@"Command"] forKey:@"Command"];
      [newClip setValue:[clip valueForKey:@"BuiltIn"] forKey:@"BuiltIn"];
			
			NSData *data = [clip valueForKey:@"Image"];
			NSImage *image = nil;
			if (data) {
				if ([data length] > 0) {
					image = [NSKeyedUnarchiver unarchiveObjectWithData:data];
				}
			}
			
			if (image == nil || ![image isValid]) {
				[newClip setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSImage imageNamed:NSImageNameRefreshTemplate]] forKey:@"Image"];						
			}
			
			[newClip setValue:[NSNumber numberWithBool:YES] forKey:@"validImage"];
      //      NSLog(@"Checking new clip %@", [newClip valueForKey:@"Code"]);
      //      NSLog(@"    command: %@", [newClip valueForKey:@"Command"]);
      // apply default command if it is currently empty
      if ([newClip valueForKey:@"Command"] == nil && [[newClip valueForKey:@"BuiltIn"] boolValue]) {
        //        [newClip setValue:@"" forKey:@"Command"];
        for (NSDictionary *dcategory in [defaultLibrary valueForKey:@"Categories"]) {
          for (NSMutableDictionary *dclip in [dcategory valueForKey:@"Contents"]) {
            NSString *command = [dclip valueForKey:@"Command"];
            if (command != nil) {
              //              NSLog(@"Default code: %@", [dclip valueForKey:@"Code"]);
              //              NSLog(@"   new clip: %@", [newClip valueForKey:@"Code"]);
              if ([[dclip valueForKey:@"Code"] isEqualToString:[newClip valueForKey:@"Code"]]) {
                //                NSLog(@"Assign command %@", command);
                [newClip setValue:command forKey:@"Command"]; 
              }
            }
          }
        }
      }
			// add the new clip to the contents
			[clips addObject:newClip];			
			[newClip release];
		}		
		[newCategory setValue:clips forKey:@"Contents"];		
		// Category is ready, add it to the array
		[categories addObject:newCategory];		
		[newCategory release];
	}
  return [categories autorelease];
}

#pragma mark -
#pragma mark Access

- (NSArray*) categories
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSError *fetchError = nil;
	NSArray *fetchResults;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Category"
																						inManagedObjectContext:moc];
	
	[fetchRequest setEntity:entity];
	fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];
	[fetchRequest release];
  
  if (fetchResults) {
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES];
    NSArray *descriptors = [NSArray arrayWithObject:descriptor];
    return [fetchResults sortedArrayUsingDescriptors:descriptors];    
  }
  
  return nil;	
}

- (NSArray*) entriesForCategory:(TPLibraryCategory*)category
{
  NSArray *entries = [category.entries allObjects];
  NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES];
  NSArray *descriptors = [NSArray arrayWithObject:descriptor];
  return [entries sortedArrayUsingDescriptors:descriptors];    
}

- (TPLibraryCategory*) categoryAtIndex:(NSInteger)index
{
  NSArray *categories = [self categories];
  return [categories objectAtIndex:index];
}

- (NSInteger)indexOfCategory:(TPLibraryCategory*)category
{
  NSArray *categories = [self categories];
  return [categories indexOfObject:category];
}

- (TPLibraryCategory*) categoryNamed:(NSString*)name
{
  NSManagedObjectContext *moc = [self managedObjectContext];
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSError *fetchError = nil;
  NSArray *fetchResults;
  
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"Category"
                                            inManagedObjectContext:moc];
  
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K like %@", @"name", name];
  [fetchRequest setPredicate:predicate];  
  [fetchRequest setEntity:entity];
  fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];
  [fetchRequest release];
  
  if (fetchResults != nil && [fetchResults count] > 0)
    return [fetchResults objectAtIndex:0];
  
  return nil;	
}

- (TPLibraryCategory*) createCategoryWithName:(NSString*)name
{
  NSEntityDescription *desc = [NSEntityDescription entityForName:@"Category" inManagedObjectContext:self.managedObjectContext];
  TPLibraryCategory *category = [[TPLibraryCategory alloc] initWithEntity:desc insertIntoManagedObjectContext:self.managedObjectContext];
  category.name = name;
  
  category.sortIndex = [NSNumber numberWithInteger:[[self categories] count]];
  [self updateSortIndices];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:TPLibraryDidUpdateNotification object:self];
  
  return [category autorelease];
}

- (TPLibraryCategory*) getOrCreateCategoryWithName:(NSString*)name
{
  TPLibraryCategory *category = [self categoryNamed:name];
  
  if (category == nil) {
    category = [self createCategoryWithName:name];
  }
  
  return category;
}

- (void) removeCategory:(TPLibraryCategory*)category
{
  [self.managedObjectContext deleteObject:category];
  [self.managedObjectContext processPendingChanges];
  [self updateSortIndices];
  [[NSNotificationCenter defaultCenter] postNotificationName:TPLibraryDidUpdateNotification object:self];
}

- (TPLibraryEntry*) clipWithCode:(NSString*)someCode inCategory:(TPLibraryCategory*)category
{
  
  // make new clip
  NSEntityDescription *desc = [NSEntityDescription entityForName:@"Entry" inManagedObjectContext:self.managedObjectContext];
  TPLibraryEntry *entry = [[TPLibraryEntry alloc] initWithEntity:desc insertIntoManagedObjectContext:self.managedObjectContext];
  entry.code = someCode;
  [category addEntriesObject:entry];
  entry.sortIndex = [NSNumber numberWithInteger:[[self entriesForCategory:category] count]];
  [self.managedObjectContext processPendingChanges];
    
  [self updateSortIndices];
  [[NSNotificationCenter defaultCenter] postNotificationName:TPLibraryDidUpdateNotification object:self];
  
  return [entry autorelease];  
}

- (void) removeEntries:(NSArray*)entriesToDelete
{
  for (TPLibraryEntry *entry in entriesToDelete) {
    [self.managedObjectContext deleteObject:entry];
  }
  [self.managedObjectContext processPendingChanges];      
  [self updateSortIndices];
  [[NSNotificationCenter defaultCenter] postNotificationName:TPLibraryDidUpdateNotification object:self];
}

- (NSArray*) entriesWithDefinedCommands
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSError *fetchError = nil;
	NSArray *fetchResults;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Entry"
																						inManagedObjectContext:moc];
	
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.command != nil"];  
  [fetchRequest setPredicate:predicate];
	[fetchRequest setEntity:entity];
	fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];
	[fetchRequest release];
  
  if (fetchResults) {
    return fetchResults;    
  }
  
  return [NSArray array];
}

- (NSString*) codeForCommand:(NSString*)command
{
  if ([command length] == 0) {
    return nil;
  }
  
  NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSError *fetchError = nil;
	NSArray *fetchResults;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Entry"
																						inManagedObjectContext:moc];
	
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.command = %@", command];  
  [fetchRequest setPredicate:predicate];
	[fetchRequest setEntity:entity];
	fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];
	[fetchRequest release];
  
  if (fetchResults && [fetchResults count] > 0) {
    NSArray *codes = [fetchResults valueForKey:@"code"];    
    return [codes objectAtIndex:0];
  }
  
  return nil;
}

- (NSArray*)commandsBeginningWith:(NSString*)prefix
{
  NSMutableArray *commands = [NSMutableArray array];
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSError *fetchError = nil;
	NSArray *fetchResults;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Entry"
																						inManagedObjectContext:moc];
  
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.command LIKE %@", [[prefix substringFromIndex:1] stringByAppendingString:@"*"]];  
  [fetchRequest setPredicate:predicate];
	[fetchRequest setEntity:entity];
	fetchResults = [moc executeFetchRequest:fetchRequest error:&fetchError];
	[fetchRequest release];
  
  if (fetchResults) {
    for (TPLibraryEntry *entry in fetchResults) {
      NSString *cmd = entry.command;
      [commands addObject:[@"#" stringByAppendingString:cmd]];
    }
  }
  
  return commands;
}


@end