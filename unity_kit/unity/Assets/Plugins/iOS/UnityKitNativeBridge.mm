/// Native bridge functions called by Unity C# via [DllImport("__Internal")].
///
/// These functions are compiled into UnityFramework.framework and forward
/// messages to FlutterBridgeRegistry (in the unity_kit Flutter plugin) via
/// Objective-C runtime lookup. This decouples the Unity build from the
/// Flutter plugin — UnityFramework links against these symbols at build
/// time, while the actual Flutter routing happens at runtime.
///
/// All callbacks dispatch to the main thread because Unity calls from its
/// render thread (iOS-C2).

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/// Maximum message size in bytes (matches FlutterBridgeRegistry.swift iOS-H1).
static const NSUInteger kMaxMessageSize = 1048576; // 1 MB

/// Cached class reference for FlutterBridgeRegistry (resolved once at runtime).
static Class _bridgeRegistryClass = nil;

static Class GetBridgeRegistryClass(void) {
    if (_bridgeRegistryClass == nil) {
        _bridgeRegistryClass = NSClassFromString(@"FlutterBridgeRegistry");
        if (_bridgeRegistryClass == nil) {
            NSLog(@"[UnityKit] FlutterBridgeRegistry class not found in runtime");
        }
    }
    return _bridgeRegistryClass;
}

extern "C" {

/// Called from Unity C# NativeAPI.SendToFlutter via [DllImport("__Internal")].
/// Validates message size (iOS-H1), then dispatches to main thread (iOS-C2)
/// and forwards to FlutterBridgeRegistry.sendMessageToFlutter(_:).
void SendMessageToFlutter(const char* message) {
    if (message == NULL) return;

    size_t length = strnlen(message, kMaxMessageSize + 1);
    if (length > kMaxMessageSize) {
        NSLog(@"[UnityKit] Message exceeds max size (%lu bytes)", (unsigned long)kMaxMessageSize);
        return;
    }

    NSString *msg = [NSString stringWithUTF8String:message];

    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = GetBridgeRegistryClass();
        if (cls == nil) {
            NSLog(@"[UnityKit] SendMessageToFlutter: bridge not available, dropping message");
            return;
        }

        SEL sel = NSSelectorFromString(@"sendMessageToFlutter:");
        if ([cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [cls performSelector:sel withObject:msg];
#pragma clang diagnostic pop
        } else {
            NSLog(@"[UnityKit] SendMessageToFlutter: selector not found on FlutterBridgeRegistry");
        }
    });
}

/// Called from Unity C# NativeAPI.NotifySceneLoaded via [DllImport("__Internal")].
/// Dispatches to main thread (iOS-C2) and forwards to
/// FlutterBridgeRegistry.sendSceneLoadedToFlutter(_:buildIndex:isLoaded:isValid:).
void SendSceneLoadedToFlutter(const char* name, int buildIndex, bool isLoaded, bool isValid) {
    NSString *sceneName = name ? [NSString stringWithUTF8String:name] : @"";
    int32_t idx = (int32_t)buildIndex;
    BOOL loaded = isLoaded ? YES : NO;
    BOOL valid = isValid ? YES : NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = GetBridgeRegistryClass();
        if (cls == nil) {
            NSLog(@"[UnityKit] SendSceneLoadedToFlutter: bridge not available");
            return;
        }

        SEL sel = NSSelectorFromString(@"sendSceneLoadedToFlutter:buildIndex:isLoaded:isValid:");
        NSMethodSignature *sig = [cls methodSignatureForSelector:sel];
        if (sig == nil) {
            NSLog(@"[UnityKit] SendSceneLoadedToFlutter: selector not found on FlutterBridgeRegistry");
            return;
        }

        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
        [invocation setSelector:sel];
        [invocation setTarget:cls];

        NSString *nameCopy = sceneName;
        [invocation setArgument:&nameCopy atIndex:2];
        int32_t idxCopy = idx;
        [invocation setArgument:&idxCopy atIndex:3];
        BOOL loadedCopy = loaded;
        [invocation setArgument:&loadedCopy atIndex:4];
        BOOL validCopy = valid;
        [invocation setArgument:&validCopy atIndex:5];

        [invocation invoke];
    });
}

} // extern "C"
