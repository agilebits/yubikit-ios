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

#import <Foundation/Foundation.h>
#import <YubiKit/YKFOTPToken.h>

typedef NS_ENUM(NSUInteger, YKFNDEFWellKnownType) {
    YKFNDEFWellKnownTypeURI  = 0x55,
    YKFNDEFWellKnownTypeText = 0x54
};

API_AVAILABLE(ios(11.0))
@protocol YKFOTPTokenParserProtocol

- (nullable id<YKFOTPTokenProtocol>)otpTokenFromNfcMessages:(nonnull NSArray *)messages;

@end

API_AVAILABLE(ios(11.0))
@interface YKFOTPTokenParser : NSObject<YKFOTPTokenParserProtocol>
@end
