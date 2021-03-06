// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <YubiKit/YKFOATHRenameAPDU.h>
#import <YubiKit/YKFKeyOATHRenameRequest.h>
#import <YubiKit/YKFAPDUCommandInstruction.h>
#import <YubiKit/YKFAssert.h>
#import <YubiKit/YKFNSMutableDataAdditions.h>
#import <YubiKit/YKFOATHCredential+Private.h>

static const UInt8 YKFOATHRenameAPDUNameTag = 0x71;

@implementation YKFOATHRenameAPDU

- (instancetype)initWithRequest:(nonnull YKFKeyOATHRenameRequest *)request {
    YKFAssertAbortInit(request);
    
    NSMutableData *rawRequest = [[NSMutableData alloc] init];
    
    // Current name
    NSString *name = request.credential.key;
    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    [rawRequest ykf_appendEntryWithTag:YKFOATHRenameAPDUNameTag data:nameData];
    
    // New name
    NSString *newName = request.renamedCredential.key;
    NSData *newNameData = [newName dataUsingEncoding:NSUTF8StringEncoding];
    [rawRequest ykf_appendEntryWithTag:YKFOATHRenameAPDUNameTag data:newNameData];
    
    return [super initWithCla:0 ins:YKFAPDUCommandInstructionOATHRename p1:0 p2:0 data:rawRequest type:YKFAPDUTypeShort];
}

@end

