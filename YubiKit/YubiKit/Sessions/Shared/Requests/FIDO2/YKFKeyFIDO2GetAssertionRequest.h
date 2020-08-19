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
#import <YubiKit/YKFKeyFIDO2Request.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name Options Keys
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    User Presence option key to set in the request options dictionary.
 
 @discussion
    Instructs the authenticator to require user consent to complete the operation. Set this key in the options
    dictionary of the request when necessary.
 */
extern NSString* const YKFKeyFIDO2GetAssertionRequestOptionUP;

/*!
 @abstract
    User Verification option key to set in the request options dictionary.
 
 @discussion
    Instructs the authenticator to require a gesture that verifies the user to complete the request. Examples of such
    gestures are fingerprint scan or a PIN. Set this key in the options dictionary of the request when necessary.
 */
extern NSString* const YKFKeyFIDO2GetAssertionRequestOptionUV;

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFKeyFIDO2GetAssertionRequest
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFKeyFIDO2GetAssertionRequest
 
 @abstract
    Request for retrieving a signature from the authenticator. This request maps to the
    authenticatorGetAssertion command from CTAP2 protocol:
    https://fidoalliance.org/specs/fido-v2.0-rd-20180702/fido-client-to-authenticator-protocol-v2.0-rd-20180702.pdf
 */
@interface YKFKeyFIDO2GetAssertionRequest: YKFKeyFIDO2Request

/*!
 @abstract
    Relying party identifier as defined in WebAuthN.
 
 @discussion
    This property is required by the key to fulfil the request. If missing, the FIDO2 Service will return an error
    when trying to execute the request.
 */
@property (nonatomic) NSString *rpId;

/*!
 @abstract
    Hash of the serialized client data collected by the host as defined in WebAuthN.
 
 @discussion
    This property is required by the key to fulfil the request. The value should be a SHA256 of the received
    Client Data from the WebAuthN server. If missing, the FIDO2 Service will return an error when trying to
    execute the request.
 */
@property (nonatomic) NSData *clientDataHash;

/*!
 @abstract
    A sequence of YKFFIDO2PublicKeyCredentialDescriptor objects, each denoting a credential. The authenticator
    will generate a signature for each credential.
 
 @discussion
    This property is optional but it's recommended to always specify a credential in the list and not make
    assumtions on the number of credentials generated by the key.
 */
@property (nonatomic, nullable) NSArray *allowList;

/*!
 @discussion
    The options provide a list of properties to influence authenticator operation when signing, as specified
    in in the table below. This parameter is optional.
 
    @code
    Key           | Default value      | Definition
    ----------------------------------------------------------------------------------------
    uv            | false              | user verification: Instructs the authenticator to
                                         require a gesture that verifies the user to complete
                                         the request. Examples of such gestures are fingerprint
                                         scan or a PIN.
    ----------------------------------------------------------------------------------------
    up            | true               | user presence: Instructs the authenticator to require
                                         user consent to complete the operation.
    @endcode
 */
@property (nonatomic, nullable) NSDictionary *options;

@end

NS_ASSUME_NONNULL_END
