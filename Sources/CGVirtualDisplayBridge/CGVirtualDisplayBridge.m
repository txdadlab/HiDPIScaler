#import "CGVirtualDisplay.h"
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

static NSMutableDictionary<NSNumber *, CGVirtualDisplay *> *sActiveVirtualDisplays = nil;

static void ensureInit(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sActiveVirtualDisplays = [NSMutableDictionary new];
    });
}

#pragma mark - Virtual Display Creation

CGDirectDisplayID HiDPICreateVirtualDisplay(
    uint32_t logicalWidth, uint32_t logicalHeight,
    double refreshRate, const char *name
) {
    ensureInit();

    @try {
        uint32_t pixelWidth  = logicalWidth * 2;
        uint32_t pixelHeight = logicalHeight * 2;

        NSString *displayName = name ? [NSString stringWithUTF8String:name]
                                     : @"HiDPI Virtual Display";

        CGVirtualDisplayDescriptor *descriptor = [[CGVirtualDisplayDescriptor alloc] init];
        if (!descriptor) { NSLog(@"[HiDPI] Failed to alloc descriptor"); return 0; }

        descriptor.name = displayName;
        descriptor.maxPixelsWide = pixelWidth;
        descriptor.maxPixelsHigh = pixelHeight;
        descriptor.sizeInMillimeters = CGSizeMake(597.0, 336.0);
        descriptor.vendorID  = 0xEEEE;
        descriptor.productID = 0x1234;
        descriptor.serialNum = 0x0001;
        descriptor.queue = dispatch_get_main_queue();
        descriptor.terminationHandler = ^{
            NSLog(@"[HiDPI] Virtual display '%@' terminated by system", displayName);
        };

        CGVirtualDisplay *virtualDisplay = [[CGVirtualDisplay alloc]
            initWithDescriptor:descriptor];
        [descriptor release];
        if (!virtualDisplay) { NSLog(@"[HiDPI] initWithDescriptor returned nil"); return 0; }

        CGDirectDisplayID displayID = [virtualDisplay displayID];
        if (displayID == 0) {
            NSLog(@"[HiDPI] Invalid display ID (0)");
            [virtualDisplay release];
            return 0;
        }

        NSLog(@"[HiDPI] Virtual display created: ID=%u", displayID);

        CGVirtualDisplaySettings *settings = [[CGVirtualDisplaySettings alloc] init];
        if (!settings) {
            NSLog(@"[HiDPI] Failed to alloc settings");
            [virtualDisplay release];
            return 0;
        }

        settings.hiDPI = 1;

        CGVirtualDisplayMode *nativeMode = [[CGVirtualDisplayMode alloc]
            initWithWidth:pixelWidth height:pixelHeight refreshRate:refreshRate];
        CGVirtualDisplayMode *hidpiMode = [[CGVirtualDisplayMode alloc]
            initWithWidth:logicalWidth height:logicalHeight refreshRate:refreshRate];

        NSMutableArray *modes = [NSMutableArray array];
        if (nativeMode) [modes addObject:nativeMode];
        if (hidpiMode)  [modes addObject:hidpiMode];
        settings.modes = modes;

        [nativeMode release];
        [hidpiMode release];

        BOOL applied = [virtualDisplay applySettings:settings];
        NSLog(@"[HiDPI] applySettings: %@", applied ? @"YES" : @"NO");
        [settings release];

        @synchronized (sActiveVirtualDisplays) {
            sActiveVirtualDisplays[@(displayID)] = virtualDisplay;
        }
        // Dictionary retains; balance our alloc
        [virtualDisplay release];

        NSLog(@"[HiDPI] Ready: ID=%u, logical=%ux%u, backing=%ux%u",
              displayID, logicalWidth, logicalHeight, pixelWidth, pixelHeight);
        return displayID;

    } @catch (NSException *exception) {
        NSLog(@"[HiDPI] Exception: %@ - %@", exception.name, exception.reason);
        return 0;
    }
}

bool HiDPIDestroyVirtualDisplay(CGDirectDisplayID displayID) {
    ensureInit();
    @synchronized (sActiveVirtualDisplays) {
        NSNumber *key = @(displayID);
        if (!sActiveVirtualDisplays[key]) return false;
        [sActiveVirtualDisplays removeObjectForKey:key];
        NSLog(@"[HiDPI] Destroyed: ID=%u", displayID);
        return true;
    }
}

void HiDPIDestroyAllVirtualDisplays(void) {
    ensureInit();
    @synchronized (sActiveVirtualDisplays) {
        [sActiveVirtualDisplays removeAllObjects];
    }
}

int HiDPIGetVirtualDisplayCount(void) {
    ensureInit();
    @synchronized (sActiveVirtualDisplays) {
        return (int)sActiveVirtualDisplays.count;
    }
}

#pragma mark - Mirroring

CGError HiDPIConfigureMirroring(CGDirectDisplayID src, CGDirectDisplayID dst) {
    CGDisplayConfigRef config = NULL;
    CGError err = CGBeginDisplayConfiguration(&config);
    if (err != kCGErrorSuccess) return err;

    err = CGConfigureDisplayMirrorOfDisplay(config, src, dst);
    if (err != kCGErrorSuccess) { CGCancelDisplayConfiguration(config); return err; }

    err = CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
    return err;
}

#pragma mark - Display Enumeration

CGError HiDPIGetActiveDisplays(CGDirectDisplayID *out, uint32_t max, uint32_t *count) {
    return CGGetActiveDisplayList(max, out, count);
}

CGDirectDisplayID HiDPIGetMainDisplayID(void) { return CGMainDisplayID(); }
bool HiDPIIsBuiltInDisplay(CGDirectDisplayID id) { return (bool)CGDisplayIsBuiltin(id); }

CGError HiDPIGetCurrentDisplayMode(
    CGDirectDisplayID displayID,
    size_t *w, size_t *h, size_t *pw, size_t *ph, double *rate
) {
    CGDisplayModeRef mode = CGDisplayCopyDisplayMode(displayID);
    if (!mode) return kCGErrorFailure;
    if (w)    *w    = CGDisplayModeGetWidth(mode);
    if (h)    *h    = CGDisplayModeGetHeight(mode);
    if (pw)   *pw   = CGDisplayModeGetPixelWidth(mode);
    if (ph)   *ph   = CGDisplayModeGetPixelHeight(mode);
    if (rate) *rate = CGDisplayModeGetRefreshRate(mode);
    CGDisplayModeRelease(mode);
    return kCGErrorSuccess;
}

void HiDPIGetDisplayPhysicalSize(CGDirectDisplayID id, double *wMM, double *hMM) {
    CGSize size = CGDisplayScreenSize(id);
    if (wMM) *wMM = size.width;
    if (hMM) *hMM = size.height;
}

CGError HiDPIGetDisplayModes(
    CGDirectDisplayID displayID,
    HiDPIDisplayModeInfo *out, uint32_t max, uint32_t *count
) {
    if (!out || !count) return kCGErrorIllegalArgument;
    *count = 0;

    NSDictionary *opts = @{
        (__bridge NSString *)kCGDisplayShowDuplicateLowResolutionModes: @YES
    };
    CFArrayRef arr = CGDisplayCopyAllDisplayModes(displayID, (__bridge CFDictionaryRef)opts);
    if (!arr) return kCGErrorFailure;

    CFIndex total = CFArrayGetCount(arr);
    uint32_t n = 0;
    for (CFIndex i = 0; i < total && n < max; i++) {
        CGDisplayModeRef m = (CGDisplayModeRef)CFArrayGetValueAtIndex(arr, i);
        if (!m) continue;
        size_t w = CGDisplayModeGetWidth(m), h = CGDisplayModeGetHeight(m);
        size_t pw = CGDisplayModeGetPixelWidth(m), ph = CGDisplayModeGetPixelHeight(m);
        out[n] = (HiDPIDisplayModeInfo){w, h, pw, ph,
            CGDisplayModeGetRefreshRate(m), (pw > w) || (ph > h)};
        n++;
    }
    CFRelease(arr);
    *count = n;
    return kCGErrorSuccess;
}
