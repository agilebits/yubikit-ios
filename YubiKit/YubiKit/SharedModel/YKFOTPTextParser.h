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
#import <YubiKit/YKFOTPTokenValidator.h>
#import <YubiKit/YKFOTPTextParserProtocol.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFOTPTextParser
 
 @abstract
    The default implementation for parsing the OTP NDEF payload whnen the type is URI. This parser checks the format
    en-US\<Text\>/\<token value\>. A usual Text payload looks like this: en-US/72403154.
 */
@interface YKFOTPTextParser : NSObject<YKFOTPTextParserProtocol>

- (nullable instancetype)initWithValidator:(id<YKFOTPTokenValidatorProtocol>)validator NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
