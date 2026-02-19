#ifndef CGVirtualDisplay_h
#define CGVirtualDisplay_h

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

// =============================================================================
// Private CoreGraphics Virtual Display API Declarations
// Sourced from macOS class-dump headers (w0lfschild/macOS_headers) and
// verified against working implementations (node-mac-virtual-display,
// FluffyDisplay, BetterDisplay).
// Stable across macOS 12+ (Monterey through Tahoe).
// =============================================================================

#pragma mark - CGVirtualDisplayMode

@interface CGVirtualDisplayMode : NSObject

@property (readonly, nonatomic) unsigned int width;
@property (readonly, nonatomic) unsigned int height;
@property (readonly, nonatomic) double refreshRate;

- (instancetype)initWithWidth:(unsigned int)width
                       height:(unsigned int)height
                  refreshRate:(double)refreshRate;

@end

#pragma mark - CGVirtualDisplaySettings

@interface CGVirtualDisplaySettings : NSObject

@property (retain, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
@property (nonatomic) unsigned int hiDPI;

@end

#pragma mark - CGVirtualDisplayDescriptor

@interface CGVirtualDisplayDescriptor : NSObject

@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) unsigned int vendorID;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int serialNum;
@property (retain, nonatomic) NSString *name;
@property (nonatomic) CGPoint redPrimary;
@property (nonatomic) CGPoint greenPrimary;
@property (nonatomic) CGPoint bluePrimary;
@property (nonatomic) CGPoint whitePoint;
@property (retain, nonatomic) dispatch_queue_t queue;
@property (copy, nonatomic) void (^terminationHandler)(void);

@end

#pragma mark - CGVirtualDisplay

@interface CGVirtualDisplay : NSObject

@property (readonly, nonatomic) unsigned int displayID;
@property (readonly, nonatomic) unsigned int hiDPI;
@property (readonly, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
@property (readonly, nonatomic) unsigned int vendorID;
@property (readonly, nonatomic) unsigned int productID;
@property (readonly, nonatomic) unsigned int serialNum;
@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) CGSize sizeInMillimeters;
@property (readonly, nonatomic) unsigned int maxPixelsWide;
@property (readonly, nonatomic) unsigned int maxPixelsHigh;

- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;

@end

#pragma mark - C Wrapper Functions

CGDirectDisplayID HiDPICreateVirtualDisplay(
    uint32_t logicalWidth, uint32_t logicalHeight,
    double refreshRate, const char *name);
bool HiDPIDestroyVirtualDisplay(CGDirectDisplayID displayID);
void HiDPIDestroyAllVirtualDisplays(void);
int HiDPIGetVirtualDisplayCount(void);
CGError HiDPIConfigureMirroring(CGDirectDisplayID src, CGDirectDisplayID dst);
CGError HiDPIGetActiveDisplays(CGDirectDisplayID *out, uint32_t max, uint32_t *count);
CGError HiDPIGetCurrentDisplayMode(CGDirectDisplayID id,
    size_t *w, size_t *h, size_t *pw, size_t *ph, double *rate);
void HiDPIGetDisplayPhysicalSize(CGDirectDisplayID id, double *wMM, double *hMM);
bool HiDPIIsBuiltInDisplay(CGDirectDisplayID id);
CGDirectDisplayID HiDPIGetMainDisplayID(void);

typedef struct {
    size_t width; size_t height;
    size_t pixelWidth; size_t pixelHeight;
    double refreshRate; bool isHiDPI;
} HiDPIDisplayModeInfo;

CGError HiDPIGetDisplayModes(CGDirectDisplayID id,
    HiDPIDisplayModeInfo *out, uint32_t max, uint32_t *count);

#endif
