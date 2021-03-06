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
#import <UIKit/UIKit.h>
#import <YubiKit/YKFViewController.h>

@class YKFQRCodeScanViewController;
@protocol YKFQRCodeScanViewControllerDelegate<NSObject>

- (void)qrCodeScanViewController:(nonnull YKFQRCodeScanViewController *)viewController didScanPayload:(nonnull NSString *)payload;
- (void)qrCodeScanViewController:(nonnull YKFQRCodeScanViewController *)viewController didFailWithError:(nonnull NSError *)error;
- (void)qrCodeScanViewControllerDidCancel:(nonnull YKFQRCodeScanViewController *)viewController;

@end

@interface YKFQRCodeScanViewController : YKFViewController

@property (nonatomic, weak, nullable) id<YKFQRCodeScanViewControllerDelegate> delegate;

@end
