//
//  TPBottomBarView.m
//  TeXnicle
//
//  Created by Martin Hewitson on 30/8/10.
//  Copyright 2010 bobsoft. All rights reserved.
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
//  DISCLAIMED. IN NO EVENT SHALL MARTIN HEWITSON OR BOBSOFT SOFTWARE BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "TETopBarView.h"


@implementation TETopBarView

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) awakeFromNib
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
				 selector:@selector(handleWindowResignedMain:)
						 name:NSApplicationDidResignActiveNotification
					 object:NSApp];
	[nc addObserver:self
				 selector:@selector(handleWindowDidBecomeMain:)
						 name:NSApplicationDidBecomeActiveNotification
					 object:NSApp];
	
//	self.endingColor = [NSColor lightGrayColor];
  CGFloat v = 237;
  self.endingColor = [NSColor colorWithDeviceRed:v/255.0 green:v/255.0 blue:v/255.0 alpha:1.0];
  self.startingColor = [NSColor colorWithDeviceRed:v/255.0 green:v/255.0 blue:v/255.0 alpha:1.0];
  self.angle = 270;
  self.cornerRadius = 0;
  self.borderWidth = 0.0;
}

#pragma mark -
#pragma mark Notification handlers

- (void) handleWindowDidBecomeMain:(NSNotification*)notification
{
//  CGFloat start = 207/255.0;
//  CGFloat end   = 168/255.0;
//  self.startingColor = [NSColor colorWithDeviceRed:start green:start blue:start alpha:1.0];
//  self.endingColor = [NSColor colorWithDeviceRed:end green:end blue:end alpha:1.0];
//	[self setNeedsDisplay:YES];
}

- (void) handleWindowResignedMain:(NSNotification*)notification
{
//  CGFloat start = 237/255.0;
//  CGFloat end   = 217/255.0;
//  self.startingColor = [NSColor colorWithDeviceRed:start green:start blue:start alpha:1.0];
//  self.endingColor = [NSColor colorWithDeviceRed:end green:end blue:end alpha:1.0];
//	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	
	// draw line along the bottom
	NSRect r = [self bounds];
	[[NSColor blackColor] set];
	NSBezierPath *path = [NSBezierPath bezierPath];
	CGFloat lineWidth = 0.5;
	[path setLineWidth:lineWidth];
	[path moveToPoint:NSMakePoint(0.0, lineWidth)];
	[path lineToPoint:NSMakePoint(r.size.width, lineWidth)];
	
  // draw line along top
  [path moveToPoint:NSMakePoint(0.0, r.size.height-lineWidth)];
  [path lineToPoint:NSMakePoint(r.size.width, r.size.height-lineWidth)];
  
  // stroke
  [path stroke];
}

@end
