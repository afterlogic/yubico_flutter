//
//  Generated file. Do not edit.
//

#import "GeneratedPluginRegistrant.h"

#if __has_include(<webview_flutter/FLTWebViewFlutterPlugin.h>)
#import <webview_flutter/FLTWebViewFlutterPlugin.h>
#else
@import webview_flutter;
#endif

#if __has_include(<yubico_flutter/YubicoFlutterPlugin.h>)
#import <yubico_flutter/YubicoFlutterPlugin.h>
#else
@import yubico_flutter;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FLTWebViewFlutterPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTWebViewFlutterPlugin"]];
  [YubicoFlutterPlugin registerWithRegistrar:[registry registrarForPlugin:@"YubicoFlutterPlugin"]];
}

@end
