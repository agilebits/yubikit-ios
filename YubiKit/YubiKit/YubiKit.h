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

#import <YubiKit/YubiKitManager.h>
#import <YubiKit/YubiKitLogger.h>
#import <YubiKit/YubiKitConfiguration.h>
#import <YubiKit/YubiKitExternalLocalization.h>
#import <YubiKit/YubiKitDeviceCapabilities.h>

#import <YubiKit/YKFOTPTextParserProtocol.h>
#import <YubiKit/YKFOTPURIParserProtocol.h>
#import <YubiKit/YKFOTPToken.h>

#import <YubiKit/YKFQRReaderSession.h>
#import <YubiKit/YKFQRCodeScanError.h>
#import <YubiKit/YKFNFCSession.h>
#import <YubiKit/YKFNFCOTPService.h>
#import <YubiKit/YKFNFCError.h>
#import <YubiKit/YKFNFCTagDescription.h>

#import <YubiKit/YKFAccessorySession.h>
#import <YubiKit/YKFAccessoryDescription.h>

#import <YubiKit/YKFKeySessionError.h>
#import <YubiKit/YKFKeyFIDO2Error.h>
#import <YubiKit/YKFKeyU2FError.h>
#import <YubiKit/YKFKeyOATHError.h>
#import <YubiKit/YKFKeyAPDUError.h>

#import <YubiKit/YKFKeyU2FService.h>
#import <YubiKit/YKFKeyFIDO2Service.h>
#import <YubiKit/YKFKeyOATHService.h>
#import <YubiKit/YKFKeyRawCommandService.h>

#import <YubiKit/YKFKeyFIDO2Request.h>
#import <YubiKit/YKFKeyFIDO2MakeCredentialRequest.h>
#import <YubiKit/YKFKeyFIDO2GetAssertionRequest.h>
#import <YubiKit/YKFKeyFIDO2VerifyPinRequest.h>
#import <YubiKit/YKFKeyFIDO2SetPinRequest.h>
#import <YubiKit/YKFKeyFIDO2ChangePinRequest.h>

#import <YubiKit/YKFPCSC.h>

#import <YubiKit/YKFNSDataAdditions.h>
#import <YubiKit/YKFWebAuthnClientData.h>

#import <YubiKit/YKFKeyOATHCalculateAllRequest.h>
