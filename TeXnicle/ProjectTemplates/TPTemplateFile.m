//
//  TPTemplateFile.m
//  TeXnicle
//
//  Created by Martin Hewitson on 16/2/12.
//  Copyright (c) 2012 bobsoft. All rights reserved.
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
//  DISCLAIMED. IN NO EVENT SHALL MARTIN HEWITSON OR BOBSOFT SOFTWARE BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "TPTemplateFile.h"
#import "NSString+FileTypes.h"
#import "MHFileReader.h"

@interface TPTemplateFile ()


@end

@implementation TPTemplateFile

- (id) initWithPath:(NSString*)aPath
{
  self = [super initWithPath:aPath];
  if (self) {
    [self readContent];
  }
  return self;
}

- (void) readContent
{
  if ([self.path pathIsText]) {
    MHFileReader *fr = [[MHFileReader alloc] init];
    NSString *str = [fr readStringFromFileAtURL:[NSURL fileURLWithPath:self.path]];
    if (str) {
      self.stringContent = str;
    }
  } else if ([self.path pathIsImage]) {
    self.dataContent = [[NSData alloc] initWithContentsOfFile:self.path];
  } else {
    // try to load text
    MHFileReader *fr = [[MHFileReader alloc] init];
    NSString *str = [fr readStringFromFileAtURL:[NSURL fileURLWithPath:self.path]];
    if (str) {
      self.stringContent = str;
    } else {
      NSLog(@"Failed to load file type (%@): this shouldn't happen", self.path);
    }
  }
}

- (void) saveContent
{
  if (self.stringContent) {
    MHFileReader *fr = [[MHFileReader alloc] init];
    [fr writeString:self.stringContent toURL:[NSURL fileURLWithPath:self.path]];
  }
}

@end
