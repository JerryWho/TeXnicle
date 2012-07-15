//
//  TPSpellCheckerListingViewController.m
//  TeXnicle
//
//  Created by Martin Hewitson on 07/07/12.
//  Copyright (c) 2012 bobsoft. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//      * Redistributions of source code must retain the above copyright
//        notice, this list of conditions and the following disclaimer.
//      * Redistributions in binary form must reproduce the above copyright
//        notice, this list of conditions and the following disclaimer in the
//        documentation and/or other materials provided with the distribution.
//  
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL DAN WOOD, MIKE ABDULLAH OR KARELIA SOFTWARE BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "TPSpellCheckerListingViewController.h"
#import "ProjectEntity.h"
#import "ProjectItemEntity.h"
#import "FileEntity.h"
#import "externs.h"
#import "ImageAndTextCell.h"

@interface TPSpellCheckerListingViewController ()

@end

@implementation TPSpellCheckerListingViewController

@synthesize delegate;
@synthesize spellCheckTimer;
@synthesize checkedFiles;
@synthesize outlineView;
@synthesize revealButton;
@synthesize correctButton;
@synthesize learnButton;
@synthesize progressIndicator;

- (id) initWithDelegate:(id<TPSpellCheckerListingDelegate>)aDelegate
{
  self = [super initWithNibName:@"TPSpellCheckerListingViewController" bundle:nil];
  if (self) {
    self.delegate = aDelegate;
    self.checkedFiles = [NSMutableArray array];
    queue = dispatch_queue_create("com.bobsoft.TeXnicle", NULL);
    dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);    
    dispatch_set_target_queue(queue,priority);
  }
  return self;
}


- (void) dealloc
{
  self.outlineView.delegate = nil;
  self.outlineView.dataSource = nil;
  self.checkedFiles = nil;
  [self stop];
	dispatch_release(queue);
  [super dealloc];
}

- (void) awakeFromNib
{
  [self.outlineView setDoubleAction:@selector(outlineViewDoubleClicked)];
  [self.outlineView setTarget:self];
  
	NSTableColumn *tableColumn = [self.outlineView tableColumnWithIdentifier:@"NameColumn"];
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	[imageAndTextCell setEditable:NO];
	[imageAndTextCell setImage:[NSImage imageNamed:@"TeXnicle_Doc"]];
  [imageAndTextCell setLineBreakMode:NSLineBreakByTruncatingTail];
	[tableColumn setDataCell:imageAndTextCell];	
  
  
  [self setupSpellChecker];
  [self performSelector:@selector(performSpellCheck) withObject:nil afterDelay:0];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  
  [nc addObserver:self
         selector:@selector(updateAllLists) 
             name:TPSpellingLanguageChangedNotification
           object:nil];
  
}

- (IBAction)learnWord:(id)sender
{  
  TPMisspelledWord *word = [self selectedWord];
  
  [[NSSpellChecker sharedSpellChecker] learnWord:word.word];
  word.parent.needsUpdate = YES;
  [self performSpellCheck];
  [self dictionaryDidLearnNewWord];
  
}

- (IBAction) correct:(id)sender
{
	
	NSRect frame = [(NSButton *)sender frame];
	NSPoint menuOrigin = [[(NSButton *)sender superview] 
												convertPoint:NSMakePoint(frame.origin.x+frame.size.width, frame.origin.y+frame.size.height)																		 
												toView:nil];
	
	NSEvent *event =  [NSEvent mouseEventWithType:NSLeftMouseDown
																			 location:menuOrigin
																	modifierFlags:NSLeftMouseDownMask // 0x100
																			timestamp:0
																	 windowNumber:[[(NSButton *)sender window] windowNumber]
																				context:[[(NSButton *)sender window] graphicsContext]
																		eventNumber:0
																		 clickCount:1
																			 pressure:1];
	
  
  // get selected word
  TPMisspelledWord *word = [self selectedWord];
  if (word == nil) {
    return;
  }
  
  NSMenu *menu = [self correctionMenuForWord:word withTarget:self];
  
	[NSMenu popUpContextMenu:menu withEvent:event forView:(NSButton *)sender];
	
	
}

- (void) selectedCorrection:(id)sender
{  
  NSString *correction = [sender title];
  
  TPMisspelledWord *word = [self selectedWord];
  
  if ([correction hasPrefix:@"Learn"]) {
    
    [[NSSpellChecker sharedSpellChecker] learnWord:word.word];
    word.parent.needsUpdate = YES;
    [self performSpellCheck];
    [self dictionaryDidLearnNewWord];
    
  } else {
  
    [self replaceMisspelledWord:word.word atRange:word.range withCorrection:correction inFile:word.parent.file];
    
  }
}

- (NSMenu*)correctionMenuForWord:(TPMisspelledWord*)word withTarget:(id)target
{
  NSMenu *theMenu = [[[NSMenu alloc] 
											initWithTitle:@"Spelling Item Context Menu"] 
										 autorelease];
	
	[theMenu setAutoenablesItems:NO];
	
//  NSLog(@"Target %@", [target class]);
  
	NSMenuItem *menuItem;
  
  if (target == self.outlineView) {
    menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Learn \u201c%@\u201d", word.word]
                                          action:@selector(selectedCorrection:)
                                   keyEquivalent:@""];
    [menuItem setTarget:target];
    [theMenu addItem:menuItem];
    [menuItem release];
    
    [theMenu addItem:[NSMenuItem separatorItem]];
  }
  
  
  menuItem = [[NSMenuItem alloc] initWithTitle:@"Possible Corrections"
                                        action:nil
                                 keyEquivalent:@""];
  [menuItem setEnabled:NO];
  [theMenu addItem:menuItem];
  [menuItem release];
  
  [theMenu addItem:[NSMenuItem separatorItem]];
  
  
  NSArray *corrections = word.corrections;
  
  for (NSString *correction in corrections) {
    menuItem = [[NSMenuItem alloc] initWithTitle:correction
                                          action:@selector(selectedCorrection:)
                                   keyEquivalent:@""];
    [menuItem setTarget:target];
    [theMenu addItem:menuItem];
    [menuItem release];
    
  }  
  
  return theMenu;
}


- (void) outlineViewDoubleClicked
{
  NSInteger row = [self.outlineView clickedRow];
  id item = [self.outlineView itemAtRow:row];
  if ([item isKindOfClass:[TPSpellCheckedFile class]]) {
    if ([self.outlineView isItemExpanded:item]) {
      [self.outlineView collapseItem:item];
    } else {
      [self.outlineView expandItem:item];
    }
  } else if ([item isKindOfClass:[TPMisspelledWord class]]) {
    TPMisspelledWord *word = (TPMisspelledWord*)item;
    [self highlightMisspelledWord:word.word atRange:word.range inFile:word.parent.file];
  }
}

// Jump to the selected bookmark
- (IBAction)jumpToSelectedWord:(id)sender
{
  TPMisspelledWord *w = [self selectedWord];
  if (w) {    
    [self highlightMisspelledWord:w.word atRange:w.range inFile:w.parent.file];
  }
}

// Returns the currently selected bookmark, or nil
- (TPMisspelledWord*)selectedWord
{
  NSInteger row = [self.outlineView selectedRow];
  id item = [self.outlineView itemAtRow:row];
  if ([item isKindOfClass:[TPMisspelledWord class]]) {
    return item;
  }
  
  return nil;
}

- (void)updateFile:(FileEntity*)aFile
{
  TPSpellCheckedFile *checkedFile = [self checkedFileForFile:aFile];
  if (checkedFile) {
    checkedFile.needsUpdate = YES;
  }
  [self performSpellCheck];
}

- (void)updateAllFilesWithExtension:(NSString*)ext
{  
  for (TPSpellCheckedFile *checkedFile in self.checkedFiles) {
    if ([[checkedFile.file extension] isEqualToString:ext]) {
      checkedFile.needsUpdate = YES;
    }
  }
  [self performSpellCheck];
}

- (void) updateAllLists
{
  for (TPSpellCheckedFile *checkedFile in self.checkedFiles) {
    checkedFile.needsUpdate = YES;
  }
  
  [self performSpellCheck];
}

- (IBAction)forceUpdate:(id)sender
{
  [self updateAllLists];
}

- (void) stop
{
  if (self.spellCheckTimer) {
    [self.spellCheckTimer invalidate];
    self.spellCheckTimer = nil;
  }
}


- (void) setupSpellChecker
{
  [self stop];
  
  if ([self performSimpleSpellCheck]) {
    self.spellCheckTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                            target:self
                                                          selector:@selector(performSpellCheck) 
                                                          userInfo:nil
                                                           repeats:YES];
    
  } else {
    self.spellCheckTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                            target:self
                                                          selector:@selector(performSpellCheck) 
                                                          userInfo:nil
                                                           repeats:YES];
    
  }
  
  
}

- (void) performSpellCheck
{
  
  // don't bother if the app is not active
  if (![[NSApplication sharedApplication] isActive]) {
    return;
  }
  
  // if we don't have a delegate, don't proceed
  if (self.delegate == nil) {
    [self stop];
    return;
  }

  if ([self performSimpleSpellCheck]) {
    [self simpleSpellCheck];
  } else {
    [self checkSpellingTimerFired]; 
  }
   
}

- (void) simpleSpellCheck
{
  if ([self shouldPerformSpellCheck] == NO) {
    return;
  }
  
  //            NSLog(@"+ Checking file %@", [file name]);
  checkingFiles++;
  [self.progressIndicator startAnimation:self];
  
  __block TPSpellCheckedFile *checkedFile = nil;
  __block BOOL addFile = NO;
  __block NSArray *words = nil;
  
  dispatch_sync(queue, ^{						
        
    NSString *string = [self stringToCheck];     
    if (string == nil) {
      return;
    }
    
    checkedFile = [self checkedFileForFile:[self fileToCheck]];
    if (checkedFile == nil) {
      checkedFile = [[[TPSpellCheckedFile alloc] initWithFile:[self fileToCheck]] autorelease];
      addFile = YES;
    }
    
    words = [self listOfMisspelledWordsFromString:string forFile:checkedFile];
    
  });

  dispatch_async(dispatch_get_main_queue(),
                 // block
                 ^{
                   checkedFile.lastCheck = [NSDate date];
                   checkedFile.words = words;
                   checkedFile.needsUpdate = NO;
                   if (addFile) {
                     [self.checkedFiles addObject:checkedFile];
                   }
                   [self.outlineView reloadData];
                   
                   [self.progressIndicator stopAnimation:self];
                   
                 });
}

- (void) checkSpellingTimerFired
{
  if (checkingFiles > 0) {
    return;
  }
  
  if ([self shouldPerformSpellCheck] == NO) {
    return;
  }
  
  NSArray *filesToCheck = [self filesToSpellCheck];
  checkingFiles = 0;
  if (filesToCheck) {
    
    NSArray *sortedItems = [filesToCheck sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
      NSString *first  = [(ProjectItemEntity*)a valueForKey:@"name"];
      NSString *second = [(ProjectItemEntity*)b valueForKey:@"name"];
      return [first compare:second]==NSOrderedDescending;
    }];

    // need to remove any checked-files which should be no longer checked
    NSMutableArray *filesToRemove = [NSMutableArray array];
    for (TPSpellCheckedFile *checkedFile in self.checkedFiles) {
      if ([sortedItems containsObject:checkedFile.file] == NO) {
        [filesToRemove addObject:checkedFile];
      }
    }
    [self.checkedFiles removeObjectsInArray:filesToRemove];
    
    
    for (FileEntity *file in sortedItems) {
      if ([[file valueForKey:@"isText"] boolValue]) {
        
        BOOL shouldCheck = NO;
        
        // File's object
        TPSpellCheckedFile *checkedFile = [self checkedFileForFile:file];
        
        if (checkedFile == nil) {
          shouldCheck = YES;
        }
        
        if (shouldCheck == NO) {
          // check the last edit time against the last checked time
          NSDate *lastEdit = [file valueForKey:@"lastEditDate"];
          NSDate *lastCheck = checkedFile.lastCheck;
          if ([lastEdit timeIntervalSinceDate:lastCheck] > 0) {
            shouldCheck = YES;
          }            
        }  
        
        if (checkedFile.needsUpdate) {
          shouldCheck = YES;
        }
        
        if (shouldCheck) {
          //            NSLog(@"+ Checking file %@", [file name]);
          checkingFiles++;
          [self.progressIndicator startAnimation:self];
          dispatch_async(queue, ^{						
            
            [self addMisspelledWordsFromFile:file];
            
          });
        } else {
          //            NSLog(@"- Not checking file %@", [file name]);
        }
      }          
    }
  }
  
//  NSLog(@"%@", self.lists);
}

- (TPSpellCheckedFile*)checkedFileForFile:(id)file
{
  
  if ([file isKindOfClass:[FileEntity class]]) {
    for (TPSpellCheckedFile *checkedFile in self.checkedFiles) {
      if (checkedFile.file == file) {
        return checkedFile;
      }
    }
  } else {
    for (TPSpellCheckedFile *checkedFile in self.checkedFiles) {
      if ([checkedFile.file isEqualToString:file]) {
        return checkedFile;
      }
    }
  }
  
  return nil;
}

- (void) addMisspelledWordsFromFile:(FileEntity*)file
{
  NSString *string = [file workingContentString];     
  
  __block BOOL addFile = NO;
  __block TPSpellCheckedFile *checkedFile = nil;
  dispatch_sync(dispatch_get_main_queue(), ^{
    checkedFile = [self checkedFileForFile:file];
    if (checkedFile == nil) {
      checkedFile = [[TPSpellCheckedFile alloc] initWithFile:file];
      addFile = YES;
    }
  });
  
  
  NSArray *words = [self listOfMisspelledWordsFromString:string forFile:checkedFile];
  
  
  dispatch_async(dispatch_get_main_queue(),
                 // block
                 ^{
                   checkedFile.lastCheck = [NSDate date];
                   checkedFile.words = words;
                   checkedFile.needsUpdate = NO;
                   if (addFile) {
                     [self.checkedFiles addObject:checkedFile];
                   }
                   [checkedFile release];
                   
                   [self.outlineView reloadData];
                   checkingFiles--;
                   
                   if (checkingFiles == 0) {
                     [self.progressIndicator stopAnimation:self];
                   }
                   
                 });
  
}

- (NSArray*)listOfMisspelledWordsFromString:(NSString*)aString forFile:(TPSpellCheckedFile*)aFile
{
  NSSpellChecker *checker = [NSSpellChecker sharedSpellChecker];
  NSMutableArray *words = [NSMutableArray array];
  NSRange range = NSMakeRange(0, 0);
  NSRange lastRange = NSMakeRange(0, 0);
  
  NSInteger misspelledWordCount = 0;
  
  while (range.location < [aString length] && misspelledWordCount <= 1000) {
    
    range = [checker checkSpellingOfString:aString startingAt:range.location];
        
    // there seems to be a bug here in checkSpellingOfString:startingAt: where it gets
    // the same word again. So we check for that.
    if (NSEqualRanges(range, lastRange)) {
//      NSLog(@"Got same range %@", NSStringFromRange(range));
      range = NSMakeRange(NSMaxRange(range), 0);
//      NSLog(@"Jumping to %@", NSStringFromRange(range));
    }
    
    if (range.location == NSNotFound) {
      break;
    }
    
    // check if we wrapped
    if (range.location < lastRange.location) {
      break;
    }
    
    // store last range
    lastRange = range;
    
    // did we get a word?
    if (NSMaxRange(range) < [aString length] && range.length > 0) {
      NSString *misspelledWord = [aString substringWithRange:range];
//      NSLog(@"Found misspelled word [%@] at %@", misspelledWord, NSStringFromRange(range));
      NSArray *corrections = [checker guessesForWordRange:range inString:aString language:nil inSpellDocumentWithTag:0];
      TPMisspelledWord *word = [TPMisspelledWord wordWithWord:misspelledWord corrections:corrections range:range parent:aFile];
      [words addObject:word];
      misspelledWordCount++;
      // move on
      range = NSMakeRange(NSMaxRange(range), 0);
//      NSLog(@"  moving on to %@", NSStringFromRange(range));
    } else {
      break;
    }
    
    
  } // end while loop
  
  return words;
}

#pragma mark -
#pragma mark Delegate

- (BOOL) performSimpleSpellCheck
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(performSimpleSpellCheck)]) {
    return [self.delegate performSimpleSpellCheck];
  }
  return NO;
}

- (NSString*)stringToCheck
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(stringToCheck)]) {
    return [self.delegate stringToCheck];
  }
  return nil;
}

- (NSString*)fileToCheck
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(fileToCheck)]) {
    return [self.delegate fileToCheck];
  }
  return nil;
}

- (NSArray*)filesToSpellCheck
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(filesToSpellCheck)]) {
    return [self.delegate filesToSpellCheck];
  }
  return [NSArray array];
}

- (BOOL)shouldPerformSpellCheck
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(shouldPerformSpellCheck)]) {
    return [self.delegate shouldPerformSpellCheck];
  }
  return NO;
}

- (void)highlightMisspelledWord:(NSString*)word atRange:(NSRange)aRange inFile:(FileEntity*)aFile
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(highlightMisspelledWord:atRange:inFile:)]) {
    [self.delegate highlightMisspelledWord:word atRange:aRange inFile:aFile];
  }
}

- (void)replaceMisspelledWord:(NSString*)word atRange:(NSRange)aRange withCorrection:(NSString*)correction inFile:(FileEntity*)aFile
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(replaceMisspelledWord:atRange:withCorrection:inFile:)]) {
    [self.delegate replaceMisspelledWord:word atRange:aRange withCorrection:correction inFile:aFile];
  }
}

- (void)dictionaryDidLearnNewWord
{
  if (self.delegate && [self.delegate respondsToSelector:@selector(dictionaryDidLearnNewWord)]) {
    [self.delegate dictionaryDidLearnNewWord];
  }
}


#pragma mark -
#pragma mark OutlineView Data Source

- (NSArray*)nonEmptyCheckedFiles
{
  NSArray *existingFiles = [self.checkedFiles retain];
  NSMutableArray *files = [NSMutableArray array];
  for (TPSpellCheckedFile *file in existingFiles) {
    if ([file.words count] > 0) {
      [files addObject:file];
    }
  }
  [existingFiles release];
  
  NSArray *sortedItems = [files sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
    NSString *first  = [[(TPSpellCheckedFile*)a valueForKey:@"file"] valueForKey:@"name"];
    NSString *second = [[(TPSpellCheckedFile*)b valueForKey:@"file"] valueForKey:@"name"];
    return [first compare:second]==NSOrderedDescending;
  }];

  return sortedItems;
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
  if (item == nil) {
    return NO;
  }
    
  if ([item isKindOfClass:[TPSpellCheckedFile class]]) {
    return YES;
  }
  
  return NO;
}

- (id) outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{  
  if ([self.outlineView isRowSelected:[self.outlineView rowForItem:item]]) {    
    return [item valueForKey:@"selectedDisplayString"];
  } else {
    return [item valueForKey:@"displayString"];
  }
}

- (BOOL) outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  if (item == nil) {
    return NO;
  }
  
  if ([item isKindOfClass:[TPSpellCheckedFile class]]) {
    return [[item valueForKey:@"words"] count] > 0;
  }
  
  return NO;
}

- (id) outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
  if (item == nil) {
    return [[self nonEmptyCheckedFiles] objectAtIndex:index];
  }
  
  return [[item valueForKey:@"words"] objectAtIndex:index];  
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
  if (item == nil) {
    return [[self nonEmptyCheckedFiles] count];
  }
  
  if ([item isKindOfClass:[TPSpellCheckedFile class]]) {
    return [[item valueForKey:@"words"] count];
  }
  
  return 0;
}

#pragma mark -
#pragma mark OutlineView Delegate

- (void) outlineView:(NSOutlineView *)anOutlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
  if (anOutlineView == self.outlineView) {
    if ([cell isMemberOfClass:[ImageAndTextCell class]]) {
      if ([item isKindOfClass:[TPSpellCheckedFile class]]) {
        [cell setImage:[NSImage imageNamed:@"TeXnicle_Doc"]];
      } else if ([item isKindOfClass:[TPMisspelledWord class]]) {
        [cell setImage:[NSImage imageNamed:@"spellingMistake"]];
      }
    }
  }
}

- (void) selectedCorrection:(NSString*)correction forMisspelledWord:(TPMisspelledWord*)word
{
  [self replaceMisspelledWord:word.word atRange:word.range withCorrection:correction inFile:word.parent.file];
}

#pragma mark -
#pragma mark Validate Buttons

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
  if (anItem == self.revealButton){
    if ([self selectedWord]) {
      return YES;
    }
  }
  
  if (anItem == self.correctButton){
    if ([self selectedWord]) {
      return YES;
    }
  }
  
  if (anItem == self.learnButton){
    if ([self selectedWord]) {
      return YES;
    }
  }
  
  return NO;
}


@end
