#import <Foundation/Foundation.h>
#import "include/KeyboardWrapper.h"
#import <objc/message.h>

@interface CBKeyboardClient : NSObject
- (float)brightnessForKeyboard:(unsigned long long)keyboardID;
- (void)setBrightness:(float)brightness forKeyboard:(unsigned long long)keyboardID;
@end

@implementation KeyboardWrapper

+ (id)sharedClient {
    static id client = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *frameworkPath = @"/System/Library/PrivateFrameworks/CoreBrightness.framework";
        NSBundle *bundle = [NSBundle bundleWithPath:frameworkPath];
        if ([bundle load]) {
            Class clientClass = NSClassFromString(@"KeyboardBrightnessClient");
            if (clientClass) {
                client = [[clientClass alloc] init];
            }
        }
    });
    return client;
}

+ (float)getBrightness {
    id client = [self sharedClient];
    if (client && [client respondsToSelector:@selector(brightnessForKeyboard:)]) {
        return ((float(*)(id, SEL, unsigned long long))objc_msgSend)(client, @selector(brightnessForKeyboard:), 1);
    }
    return 0.0f;
}

+ (void)setBrightness:(float)brightness {
    id client = [self sharedClient];
    if (client && [client respondsToSelector:@selector(setBrightness:forKeyboard:)]) {
        ((void(*)(id, SEL, float, unsigned long long))objc_msgSend)(client, @selector(setBrightness:forKeyboard:), brightness, 1);
    }
}

@end
