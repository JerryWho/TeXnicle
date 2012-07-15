//
//  TPFileMonitor.h
//  TeXnicle
//
//  Created by Martin Hewitson on 25/7/11.
//  Copyright 2011 bobsoft. All rights reserved.
//
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

// Monitor a set of files. 
// 1) Get the list of files from the delegate. 
// 2) Check the fileLoadDate of each file against the modified time on disk
//    Check the originalContents against the current contents?
// 3) If the modified time is newer, tell the delegate

#import <Foundation/Foundation.h>

@class TPFileMonitor;

@protocol TPFileMonitorDelegate <NSObject>

- (NSArray*) fileMonitorFileList:(TPFileMonitor*)aMonitor;
- (void) fileMonitor:(TPFileMonitor*)aMonitor fileChangedOnDisk:(id)file modifiedDate:(NSDate*)modified;
- (void) fileMonitor:(TPFileMonitor*)aMonitor fileWasAccessedOnDisk:(id)file accessDate:(NSDate*)access;
- (NSString*)fileMonitor:(TPFileMonitor*)aMonitor pathOnDiskForFile:(id)file;

@end

@interface TPFileMonitor : NSObject <TPFileMonitorDelegate> {
@private
  NSTimer *timer;
  id<TPFileMonitorDelegate> delegate;
}

@property (retain) NSTimer *timer;
@property (assign) id<TPFileMonitorDelegate> delegate;

- (id)initWithDelegate:(id<TPFileMonitorDelegate>)aDelegate;
+ (TPFileMonitor*)monitorWithDelegate:(id<TPFileMonitorDelegate>)aDelegate;

- (void)checkFilesTimerFired:(NSTimer*)theTimer;
- (void) stopTimer;

@end
