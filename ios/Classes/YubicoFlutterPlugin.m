#import "YubicoFlutterPlugin.h"
#if __has_include(<yubico_flutter/yubico_flutter-Swift.h>)
#import <yubico_flutter/yubico_flutter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "yubico_flutter-Swift.h"
#endif

@implementation YubicoFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftYubicoFlutterPlugin registerWithRegistrar:registrar];
}
@end
