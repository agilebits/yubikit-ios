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

#import <YubiKit/YKFKeyService.h>
#import <YubiKit/YKFKeyService+Private.h>
#import <YubiKit/YKFAccessoryConnectionController.h>
#import <YubiKit/YKFNSDataAdditions.h>
#import <YubiKit/YKFNSDataAdditions+Private.h>
#import <YubiKit/YKFKeyAPDUError.h>
#import <YubiKit/YKFAssert.h>

@implementation YKFKeyService

#pragma mark - Key Response

+ (NSData *)dataFromKeyResponse:(NSData *)response {
    YKFParameterAssertReturnValue(response, [NSData data]);
    YKFAssertReturnValue(response.length >= 2, @"Key response data is too short.", [NSData data]);
    
    if (response.length == 2) {
        return [NSData data];
    } else {
        NSRange range = {0, response.length - 2};
        return [response subdataWithRange:range];
    }
}

#pragma mark - Status Code

+ (UInt16)statusCodeFromKeyResponse:(NSData *)response {
    YKFParameterAssertReturnValue(response, YKFKeyAPDUErrorCodeWrongLength);
    YKFAssertReturnValue(response.length >= 2, @"Key response data is too short.", YKFKeyAPDUErrorCodeWrongLength);
    
    return [response ykf_getBigEndianIntegerInRange:NSMakeRange([response length] - 2, 2)];
}

+ (UInt8)shortStatusCodeFromStatusCode:(UInt16)statusCode {
    return (UInt8)(statusCode >> 8);
}

#pragma mark - YKFKeyServiceDelegate

- (void)keyService:(YKFKeyService *)service willExecuteRequest:(YKFKeyRequest *)request {
    // Does nothing: override this in the service subclasses when necessary.
}

@end
