//
//  SonoraWaveBackgroundViews.m
//  Sonora
//

#import "SonoraWaveBackgroundViews.h"

#import <QuartzCore/QuartzCore.h>

#import "SonoraServices.h"

static UIColor *SonoraBlendColor(UIColor *from, UIColor *to, CGFloat ratio) {
    ratio = MIN(MAX(ratio, 0.0), 1.0);
    CGFloat fr = 0.0, fg = 0.0, fb = 0.0, fa = 1.0;
    CGFloat tr = 0.0, tg = 0.0, tb = 0.0, ta = 1.0;
    [from getRed:&fr green:&fg blue:&fb alpha:&fa];
    [to getRed:&tr green:&tg blue:&tb alpha:&ta];
    return [UIColor colorWithRed:(fr + ((tr - fr) * ratio))
                           green:(fg + ((tg - fg) * ratio))
                            blue:(fb + ((tb - fb) * ratio))
                           alpha:(fa + ((ta - fa) * ratio))];
}

static NSArray<UIColor *> *SonoraWavePaletteFromImage(UIImage *image) {
    if (image == nil || image.CGImage == nil) {
        return @[];
    }

    const size_t width = 28;
    const size_t height = 28;
    const size_t bytesPerRow = width * 4;
    uint8_t *pixels = calloc(height, bytesPerRow);
    if (pixels == NULL) {
        return @[];
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == nil) {
        free(pixels);
        return @[];
    }

    CGContextRef bitmapContext = CGBitmapContextCreate(pixels,
                                                       width,
                                                       height,
                                                       8,
                                                       bytesPerRow,
                                                       colorSpace,
                                                       (CGBitmapInfo)(kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(colorSpace);
    if (bitmapContext == NULL) {
        free(pixels);
        return @[];
    }
    CGContextDrawImage(bitmapContext, CGRectMake(0.0, 0.0, width, height), image.CGImage);

    typedef struct {
        CGFloat w;
        CGFloat r;
        CGFloat g;
        CGFloat b;
    } SonoraWaveBucket;
    SonoraWaveBucket buckets[10] = {0};

    for (size_t y = 0; y < height; y += 1) {
        for (size_t x = 0; x < width; x += 1) {
            size_t offset = (y * bytesPerRow) + (x * 4);
            CGFloat alpha = ((CGFloat)pixels[offset + 3]) / 255.0;
            if (alpha < 0.18) {
                continue;
            }

            CGFloat red = ((CGFloat)pixels[offset + 0]) / 255.0;
            CGFloat green = ((CGFloat)pixels[offset + 1]) / 255.0;
            CGFloat blue = ((CGFloat)pixels[offset + 2]) / 255.0;
            UIColor *c = [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
            CGFloat hue = 0.0, saturation = 0.0, brightness = 0.0;
            if (![c getHue:&hue saturation:&saturation brightness:&brightness alpha:nil]) {
                continue;
            }
            if (saturation < 0.10 || brightness < 0.12) {
                continue;
            }

            NSUInteger bucketIndex = MIN((NSUInteger)floor(hue * 10.0), (NSUInteger)9);
            CGFloat weight = 0.32 + (saturation * 0.44) + (brightness * 0.24);
            buckets[bucketIndex].w += weight;
            buckets[bucketIndex].r += red * weight;
            buckets[bucketIndex].g += green * weight;
            buckets[bucketIndex].b += blue * weight;
        }
    }

    CGContextRelease(bitmapContext);
    free(pixels);

    NSMutableArray<NSDictionary *> *ranked = [NSMutableArray array];
    for (NSUInteger idx = 0; idx < 10; idx += 1) {
        if (buckets[idx].w <= 0.0) {
            continue;
        }
        [ranked addObject:@{
            @"index": @(idx),
            @"weight": @(buckets[idx].w)
        }];
    }
    [ranked sortUsingComparator:^NSComparisonResult(NSDictionary * _Nonnull left, NSDictionary * _Nonnull right) {
        return [right[@"weight"] compare:left[@"weight"]];
    }];

    NSMutableArray<UIColor *> *colors = [NSMutableArray array];
    NSUInteger maxCount = MIN(ranked.count, (NSUInteger)4);
    for (NSUInteger rank = 0; rank < maxCount; rank += 1) {
        NSUInteger idx = [ranked[rank][@"index"] unsignedIntegerValue];
        CGFloat w = MAX(0.0001, buckets[idx].w);
        UIColor *color = [UIColor colorWithRed:(buckets[idx].r / w)
                                         green:(buckets[idx].g / w)
                                          blue:(buckets[idx].b / w)
                                         alpha:1.0];

        CGFloat hue = 0.0, sat = 0.0, bri = 0.0;
        if ([color getHue:&hue saturation:&sat brightness:&bri alpha:nil]) {
            sat = MAX(sat, 0.22);
            bri = MIN(MAX(bri, 0.30), 0.90);
            color = [UIColor colorWithHue:hue saturation:sat brightness:bri alpha:1.0];
        }
        [colors addObject:color];
    }

    return colors;
}

NSArray<UIColor *> *SonoraResolvedWavePalette(UIImage * _Nullable image) {
    NSArray<UIColor *> *palette = SonoraWavePaletteFromImage(image);
    if (palette.count >= 4) {
        return palette;
    }

    UIColor *accent = [SonoraArtworkAccentColorService dominantAccentColorForImage:image
                                                                       fallback:[UIColor colorWithRed:0.41 green:0.35 blue:0.29 alpha:1.0]];

    CGFloat hue = 0.0, sat = 0.0, bri = 0.0, alpha = 1.0;
    if ([accent getHue:&hue saturation:&sat brightness:&bri alpha:&alpha]) {
        UIColor *lifted = [UIColor colorWithHue:hue
                                      saturation:MAX(0.20, sat * 0.86)
                                      brightness:MIN(0.96, bri + 0.20)
                                           alpha:1.0];
        UIColor *deep = [UIColor colorWithHue:fmod(hue + 0.06, 1.0)
                                    saturation:MAX(0.22, sat * 0.80)
                                    brightness:MAX(0.34, bri * 0.72)
                                         alpha:1.0];
        UIColor *adjacent = [UIColor colorWithHue:fmod(hue + 0.88, 1.0)
                                        saturation:MAX(0.18, sat * 0.70)
                                        brightness:MAX(0.40, bri * 0.82)
                                             alpha:1.0];
        return @[accent, lifted, deep, adjacent];
    }

    UIColor *warm = [UIColor colorWithRed:0.58 green:0.47 blue:0.35 alpha:1.0];
    UIColor *soft = [UIColor colorWithRed:0.43 green:0.48 blue:0.44 alpha:1.0];
    return @[
        accent,
        SonoraBlendColor(accent, UIColor.whiteColor, 0.24),
        SonoraBlendColor(accent, warm, 0.20),
        SonoraBlendColor(accent, soft, 0.18)
    ];
}

static CGFloat SonoraLayerPresentationFloat(CALayer *layer, NSString *keyPath, CGFloat fallback) {
    id presentationValue = [layer.presentationLayer valueForKeyPath:keyPath];
    if ([presentationValue respondsToSelector:@selector(doubleValue)]) {
        return (CGFloat)[presentationValue doubleValue];
    }
    id modelValue = [layer valueForKeyPath:keyPath];
    if ([modelValue respondsToSelector:@selector(doubleValue)]) {
        return (CGFloat)[modelValue doubleValue];
    }
    return fallback;
}

static CGPathRef SonoraShapeLayerPresentationPath(CAShapeLayer *layer) {
    return ((CAShapeLayer *)layer.presentationLayer).path ?: layer.path;
}

static CATransform3D SonoraWaveTransform(CGFloat scale, CGFloat rotation) {
    CATransform3D transform = CATransform3DIdentity;
    transform = CATransform3DScale(transform, scale, scale, 1.0f);
    transform = CATransform3DRotate(transform, rotation, 0.0f, 0.0f, 1.0f);
    return transform;
}

@interface SonoraWaveAnimatedBackgroundView ()

@property (nonatomic, strong) CAGradientLayer *baseGradientLayer;
@property (nonatomic, strong) CAGradientLayer *haloLayer;
@property (nonatomic, strong) CAGradientLayer *coreGlowLayer;
@property (nonatomic, strong) CALayer *lineContainerLayer;
@property (nonatomic, strong) CAGradientLayer *lineMaskLayer;
@property (nonatomic, strong) NSArray<CAShapeLayer *> *lineLayers;
@property (nonatomic, strong) CAGradientLayer *vignetteLayer;
@property (nonatomic, strong) CAGradientLayer *edgeFadeMaskLayer;
@property (nonatomic, copy) NSArray<UIColor *> *currentPalette;
@property (nonatomic, assign) BOOL hasStartedAnimations;
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) CGFloat pulseSeed;
@property (nonatomic, assign) CGSize configuredSize;
@property (nonatomic, copy, nullable) NSString *currentTrackIdentifier;
@property (nonatomic, assign) NSUInteger geometryTransitionGeneration;
@property (nonatomic, copy) NSArray<UIBezierPath *> *cachedLinePaths;
@property (nonatomic, copy) NSArray<NSNumber *> *cachedLineOpacities;
@property (nonatomic, copy) NSArray<NSNumber *> *cachedLineShadowOpacities;
@property (nonatomic, copy) NSArray<NSNumber *> *cachedLineScales;
@property (nonatomic, copy) NSArray<NSNumber *> *cachedLineRotations;
@property (nonatomic, assign) CGFloat cachedLineContainerOpacity;
@property (nonatomic, assign) CGFloat cachedHaloOpacity;
@property (nonatomic, assign) CGFloat cachedCoreOpacity;
@property (nonatomic, assign) CGFloat cachedHaloScale;
@property (nonatomic, assign) CGFloat cachedCoreScale;
@property (nonatomic, assign) BOOL hasCachedAnimationSnapshot;

@end

@implementation SonoraWaveAnimatedBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.pulseSeed = 0.43f;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.clipsToBounds = NO;

    CAGradientLayer *base = [CAGradientLayer layer];
    base.type = kCAGradientLayerRadial;
    base.startPoint = CGPointMake(0.50, 0.50);
    base.endPoint = CGPointMake(1.0, 1.0);
    base.colors = @[
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor
    ];
    base.locations = @[@0.0, @0.22, @0.58, @1.0];
    [self.layer addSublayer:base];
    self.baseGradientLayer = base;

    CAGradientLayer *halo = [CAGradientLayer layer];
    halo.type = kCAGradientLayerRadial;
    halo.startPoint = CGPointMake(0.62, 0.42);
    halo.endPoint = CGPointMake(1.0, 1.0);
    halo.colors = @[
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor
    ];
    halo.locations = @[@0.0, @0.42, @1.0];
    halo.opacity = 0.90;
    [self.layer addSublayer:halo];
    self.haloLayer = halo;

    CAGradientLayer *coreGlow = [CAGradientLayer layer];
    coreGlow.type = kCAGradientLayerRadial;
    coreGlow.startPoint = CGPointMake(0.50, 0.52);
    coreGlow.endPoint = CGPointMake(1.0, 1.0);
    coreGlow.colors = @[
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor
    ];
    coreGlow.locations = @[@0.0, @0.22, @0.52, @1.0];
    coreGlow.opacity = 0.0f;
    [self.layer addSublayer:coreGlow];
    self.coreGlowLayer = coreGlow;

    CALayer *lineContainer = [CALayer layer];
    [self.layer addSublayer:lineContainer];
    self.lineContainerLayer = lineContainer;

    CAGradientLayer *lineMask = [CAGradientLayer layer];
    lineMask.type = kCAGradientLayerRadial;
    lineMask.startPoint = CGPointMake(0.50, 0.52);
    lineMask.endPoint = CGPointMake(1.0, 1.0);
    lineMask.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.88].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.72].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    lineMask.locations = @[@0.0, @0.16, @0.46, @0.82, @1.0];
    lineContainer.mask = lineMask;
    self.lineMaskLayer = lineMask;

    NSMutableArray<CAShapeLayer *> *lines = [NSMutableArray arrayWithCapacity:7];
    for (NSUInteger idx = 0; idx < 7; idx += 1) {
        CAShapeLayer *line = [CAShapeLayer layer];
        line.fillColor = UIColor.clearColor.CGColor;
        line.strokeColor = UIColor.whiteColor.CGColor;
        line.lineCap = kCALineCapRound;
        line.lineJoin = kCALineJoinRound;
        line.opacity = 0.0f;
        line.shadowColor = UIColor.whiteColor.CGColor;
        line.shadowOpacity = 0.22f;
        line.shadowRadius = 10.0f;
        line.shadowOffset = CGSizeZero;
        [lineContainer addSublayer:line];
        [lines addObject:line];
    }
    self.lineLayers = [lines copy];

    CAGradientLayer *vignette = [CAGradientLayer layer];
    vignette.type = kCAGradientLayerRadial;
    vignette.startPoint = CGPointMake(0.50, 0.52);
    vignette.endPoint = CGPointMake(1.0, 1.0);
    vignette.colors = @[
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor,
        (__bridge id)UIColor.clearColor.CGColor
    ];
    vignette.locations = @[@0.56, @0.82, @1.0];
    [self.layer addSublayer:vignette];
    self.vignetteLayer = vignette;

    CAGradientLayer *edgeFadeMask = [CAGradientLayer layer];
    edgeFadeMask.startPoint = CGPointMake(0.50, 0.0);
    edgeFadeMask.endPoint = CGPointMake(0.50, 1.0);
    edgeFadeMask.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.86].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    edgeFadeMask.locations = @[@0.0, @0.14, @0.24, @0.92, @1.0];
    self.layer.mask = edgeFadeMask;
    self.edgeFadeMaskLayer = edgeFadeMask;
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (newWindow == nil) {
        [self captureAnimationSnapshot];
    }
    [super willMoveToWindow:newWindow];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window != nil) {
        [self restoreAnimationSnapshotIfNeeded];
        [self ensureAnimationsRunning];
    }
}

- (void)captureAnimationSnapshot {
    if (self.lineLayers.count == 0) {
        return;
    }

    NSMutableArray<UIBezierPath *> *paths = [NSMutableArray arrayWithCapacity:self.lineLayers.count];
    NSMutableArray<NSNumber *> *opacities = [NSMutableArray arrayWithCapacity:self.lineLayers.count];
    NSMutableArray<NSNumber *> *shadowOpacities = [NSMutableArray arrayWithCapacity:self.lineLayers.count];
    NSMutableArray<NSNumber *> *scales = [NSMutableArray arrayWithCapacity:self.lineLayers.count];
    NSMutableArray<NSNumber *> *rotations = [NSMutableArray arrayWithCapacity:self.lineLayers.count];

    [self.lineLayers enumerateObjectsUsingBlock:^(CAShapeLayer * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        (void)stop;
        CGPathRef currentPath = SonoraShapeLayerPresentationPath(line);
        [paths addObject:(currentPath != NULL) ? [UIBezierPath bezierPathWithCGPath:currentPath] : [UIBezierPath bezierPath]];
        [opacities addObject:@(SonoraLayerPresentationFloat(line, @"opacity", line.opacity))];
        [shadowOpacities addObject:@(SonoraLayerPresentationFloat(line, @"shadowOpacity", line.shadowOpacity))];
        [scales addObject:@(SonoraLayerPresentationFloat(line, @"transform.scale", 1.0f))];
        [rotations addObject:@(SonoraLayerPresentationFloat(line, @"transform.rotation.z", 0.0f))];
    }];

    self.cachedLinePaths = paths.copy;
    self.cachedLineOpacities = opacities.copy;
    self.cachedLineShadowOpacities = shadowOpacities.copy;
    self.cachedLineScales = scales.copy;
    self.cachedLineRotations = rotations.copy;
    self.cachedLineContainerOpacity = SonoraLayerPresentationFloat(self.lineContainerLayer, @"opacity", self.lineContainerLayer.opacity);
    self.cachedHaloOpacity = SonoraLayerPresentationFloat(self.haloLayer, @"opacity", self.haloLayer.opacity);
    self.cachedCoreOpacity = SonoraLayerPresentationFloat(self.coreGlowLayer, @"opacity", self.coreGlowLayer.opacity);
    self.cachedHaloScale = SonoraLayerPresentationFloat(self.haloLayer, @"transform.scale", 1.0f);
    self.cachedCoreScale = SonoraLayerPresentationFloat(self.coreGlowLayer, @"transform.scale", 1.0f);
    self.hasCachedAnimationSnapshot = YES;
}

- (void)restoreAnimationSnapshotIfNeeded {
    if (!self.hasCachedAnimationSnapshot) {
        return;
    }

    NSUInteger lineCount = MIN(self.lineLayers.count, self.cachedLinePaths.count);
    for (NSUInteger idx = 0; idx < lineCount; idx += 1) {
        CAShapeLayer *line = self.lineLayers[idx];
        UIBezierPath *cachedPath = self.cachedLinePaths[idx];
        if ([cachedPath isKindOfClass:UIBezierPath.class]) {
            line.path = cachedPath.CGPath;
        }
        if (idx < self.cachedLineOpacities.count) {
            line.opacity = self.cachedLineOpacities[idx].floatValue;
        }
        if (idx < self.cachedLineShadowOpacities.count) {
            line.shadowOpacity = self.cachedLineShadowOpacities[idx].floatValue;
        }
        CGFloat scale = (idx < self.cachedLineScales.count) ? self.cachedLineScales[idx].floatValue : 1.0f;
        CGFloat rotation = (idx < self.cachedLineRotations.count) ? self.cachedLineRotations[idx].floatValue : 0.0f;
        line.transform = SonoraWaveTransform(scale, rotation);
    }

    self.lineContainerLayer.opacity = self.cachedLineContainerOpacity;
    self.haloLayer.opacity = self.cachedHaloOpacity;
    self.coreGlowLayer.opacity = self.cachedCoreOpacity;
    self.haloLayer.transform = CATransform3DMakeScale(self.cachedHaloScale, self.cachedHaloScale, 1.0f);
    self.coreGlowLayer.transform = CATransform3DMakeScale(self.cachedCoreScale, self.cachedCoreScale, 1.0f);

    self.hasCachedAnimationSnapshot = NO;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.baseGradientLayer.frame = self.bounds;
    self.haloLayer.frame = self.bounds;
    self.coreGlowLayer.frame = self.bounds;
    self.lineContainerLayer.frame = self.bounds;
    self.lineMaskLayer.frame = self.bounds;
    self.vignetteLayer.frame = self.bounds;
    self.edgeFadeMaskLayer.frame = self.bounds;

    if (!CGSizeEqualToSize(self.configuredSize, self.bounds.size)) {
        self.configuredSize = self.bounds.size;
        [self configureLineGeometry];
        [self restartAnimations];
    } else if (!self.hasStartedAnimations) {
        [self startAnimationsIfNeeded];
        [self restartAnimations];
    }
}

- (void)startAnimationsIfNeeded {
    if (self.hasStartedAnimations) {
        return;
    }
    self.hasStartedAnimations = YES;
}

- (void)setPlaying:(BOOL)playing {
    if (_playing == playing) {
        [self updatePlaybackStateAnimated:NO];
        return;
    }
    _playing = playing;
    [self updatePlaybackStateAnimated:YES];
}

- (void)setPulseSeedWithTrackIdentifier:(NSString * _Nullable)identifier {
    NSString *normalizedIdentifier = (identifier.length > 0) ? identifier : nil;
    if ((self.currentTrackIdentifier == nil && normalizedIdentifier == nil) ||
        [self.currentTrackIdentifier isEqualToString:normalizedIdentifier]) {
        return;
    }
    self.currentTrackIdentifier = normalizedIdentifier;

    const char *utf8 = normalizedIdentifier.UTF8String;
    if (utf8 == NULL || utf8[0] == '\0') {
        self.pulseSeed = 0.43f;
        if (!CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
            [self transitionToUpdatedGeometry];
        }
        return;
    }

    uint64_t hash = 1469598103934665603ULL;
    const uint8_t *bytes = (const uint8_t *)utf8;
    while (*bytes != 0) {
        hash ^= (uint64_t)(*bytes);
        hash *= 1099511628211ULL;
        bytes += 1;
    }
    self.pulseSeed = (CGFloat)((hash % 1000ULL) / 1000.0);
    if (!CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
        [self transitionToUpdatedGeometry];
    }
}

- (void)applyPalette:(NSArray<UIColor *> *)palette animated:(BOOL)animated {
    NSArray<UIColor *> *resolved = (palette.count >= 4) ? palette : SonoraResolvedWavePalette(nil);
    self.currentPalette = resolved;
    BOOL lightTheme = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight);

    NSArray *baseColors = @[
        (__bridge id)[[(lightTheme
                        ? SonoraBlendColor(resolved[1], UIColor.whiteColor, 0.90)
                        : SonoraBlendColor(resolved[0], UIColor.blackColor, 0.42))
                       colorWithAlphaComponent:(lightTheme ? 0.16 : 0.28)] CGColor],
        (__bridge id)[[(lightTheme
                        ? SonoraBlendColor(resolved[2], UIColor.whiteColor, 0.92)
                        : SonoraBlendColor(resolved[2], UIColor.blackColor, 0.56))
                       colorWithAlphaComponent:(lightTheme ? 0.08 : 0.15)] CGColor],
        (__bridge id)[[(lightTheme
                        ? SonoraBlendColor(resolved[0], UIColor.whiteColor, 0.97)
                        : SonoraBlendColor(resolved[3], UIColor.blackColor, 0.76))
                       colorWithAlphaComponent:(lightTheme ? 0.02 : 0.04)] CGColor],
        (__bridge id)[UIColor clearColor].CGColor
    ];
    if (animated) {
        CABasicAnimation *baseAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        baseAnim.fromValue = self.baseGradientLayer.colors;
        baseAnim.toValue = baseColors;
        baseAnim.duration = 2.0;
        baseAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.baseGradientLayer addAnimation:baseAnim forKey:@"sonora_wave_base_colors"];
    }
    self.baseGradientLayer.colors = baseColors;

    UIColor *haloColor = lightTheme
    ? SonoraBlendColor(resolved[3], UIColor.whiteColor, 0.68)
    : SonoraBlendColor(resolved[3], UIColor.whiteColor, 0.18);
    NSArray *haloColors = @[
        (__bridge id)[haloColor colorWithAlphaComponent:(lightTheme ? 0.22 : 0.28)].CGColor,
        (__bridge id)[haloColor colorWithAlphaComponent:(lightTheme ? 0.07 : 0.10)].CGColor,
        (__bridge id)[haloColor colorWithAlphaComponent:0.0].CGColor
    ];
    if (animated) {
        CABasicAnimation *haloAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        haloAnim.fromValue = self.haloLayer.colors;
        haloAnim.toValue = haloColors;
        haloAnim.duration = 2.0;
        haloAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.haloLayer addAnimation:haloAnim forKey:@"sonora_wave_halo_colors"];
    }
    self.haloLayer.colors = haloColors;

    UIColor *coreColor = lightTheme
    ? SonoraBlendColor(resolved[2], UIColor.whiteColor, 0.58)
    : SonoraBlendColor(resolved[2], UIColor.whiteColor, 0.08);
    NSArray *coreGlowColors = @[
        (__bridge id)[coreColor colorWithAlphaComponent:(lightTheme ? 0.22 : 0.20)].CGColor,
        (__bridge id)[coreColor colorWithAlphaComponent:(lightTheme ? 0.08 : 0.07)].CGColor,
        (__bridge id)[coreColor colorWithAlphaComponent:0.0].CGColor
    ];
    if (animated) {
        CABasicAnimation *coreAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        coreAnim.fromValue = self.coreGlowLayer.colors;
        coreAnim.toValue = coreGlowColors;
        coreAnim.duration = 2.2;
        coreAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.coreGlowLayer addAnimation:coreAnim forKey:@"sonora_wave_core_colors"];
    }
    self.coreGlowLayer.colors = coreGlowColors;

    NSArray<UIColor *> *lineColors = @[
        lightTheme ? SonoraBlendColor(resolved[3], UIColor.whiteColor, 0.14) : SonoraBlendColor(resolved[3], UIColor.whiteColor, 0.06),
        lightTheme ? SonoraBlendColor(resolved[1], UIColor.whiteColor, 0.20) : SonoraBlendColor(resolved[1], UIColor.whiteColor, 0.08),
        lightTheme ? SonoraBlendColor(resolved[2], UIColor.whiteColor, 0.16) : SonoraBlendColor(resolved[2], UIColor.whiteColor, 0.06),
        lightTheme ? SonoraBlendColor(resolved[0], UIColor.whiteColor, 0.10) : SonoraBlendColor(resolved[0], UIColor.whiteColor, 0.02)
    ];
    [self.lineLayers enumerateObjectsUsingBlock:^(CAShapeLayer * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        UIColor *color = lineColors[idx % lineColors.count];
        CGFloat alpha = lightTheme ? (idx < 3 ? 0.88f : 0.68f) : (idx < 3 ? 1.0f : 0.82f);
        CGColorRef strokeColor = [color colorWithAlphaComponent:alpha].CGColor;
        if (animated) {
            CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            anim.fromValue = (__bridge id)line.strokeColor;
            anim.toValue = (__bridge id)strokeColor;
            anim.duration = 1.8;
            anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [line addAnimation:anim forKey:[NSString stringWithFormat:@"sonora_wave_line_color_%lu", (unsigned long)idx]];
        }
        line.strokeColor = strokeColor;
        line.shadowColor = strokeColor;
        line.shadowOpacity = lightTheme ? (idx < 3 ? 0.30f : 0.16f) : (idx < 3 ? 0.50f : 0.30f);
        line.shadowRadius = (idx < 2) ? 18.0f : ((idx < 4) ? 12.0f : 8.0f);
    }];

    NSArray *vignetteColors = @[
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (__bridge id)[[(lightTheme
                        ? SonoraBlendColor(resolved[0], UIColor.whiteColor, 0.98)
                        : SonoraBlendColor(resolved[0], UIColor.blackColor, 0.86))
                       colorWithAlphaComponent:(lightTheme ? 0.015 : 0.028)] CGColor],
        (__bridge id)[[(lightTheme
                        ? SonoraBlendColor(resolved[3], UIColor.whiteColor, 0.995)
                        : SonoraBlendColor(resolved[3], UIColor.blackColor, 0.94))
                       colorWithAlphaComponent:(lightTheme ? 0.040 : 0.12)] CGColor]
    ];
    if (animated) {
        CABasicAnimation *vignetteAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        vignetteAnim.fromValue = self.vignetteLayer.colors;
        vignetteAnim.toValue = vignetteColors;
        vignetteAnim.duration = 1.8;
        vignetteAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.vignetteLayer addAnimation:vignetteAnim forKey:@"sonora_wave_vignette_colors"];
    }
    self.vignetteLayer.colors = vignetteColors;
    [self updatePlaybackStateAnimated:NO];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self applyPalette:(self.currentPalette ?: SonoraResolvedWavePalette(nil)) animated:NO];
        }
    }
}

- (void)configureLineGeometry {
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    if (width <= 1.0 || height <= 1.0) {
        return;
    }

    CGFloat scale = MAX(0.92f, MIN(1.20f, MIN(width / 360.0f, height / 220.0f)));
    NSArray<NSNumber *> *lineWidths = @[
        @(2.8f * scale),
        @(2.5f * scale),
        @(2.2f * scale),
        @(1.9f * scale),
        @(1.7f * scale),
        @(1.5f * scale),
        @(1.2f * scale)
    ];

    [self.lineLayers enumerateObjectsUsingBlock:^(CAShapeLayer * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        line.frame = self.bounds;
        line.lineWidth = lineWidths[idx].doubleValue;
        line.path = [self contourPathForIndex:idx variant:0].CGPath;
    }];
}

- (UIBezierPath *)contourPathForIndex:(NSUInteger)index variant:(NSUInteger)variant {
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat count = MAX(1.0f, (CGFloat)(self.lineLayers.count - 1));
    CGFloat progress = ((CGFloat)index) / count;
    CGFloat phase = (self.pulseSeed * (CGFloat)(M_PI * 2.0)) + (((CGFloat)variant) * 0.86f) + (progress * 1.15f);

    CGFloat centerX = (width * 0.50f) + (sinf(phase * 0.72f) * width * 0.018f);
    CGFloat centerY = (height * 0.53f) + (cosf((phase * 0.54f) + 0.6f) * height * 0.022f);
    CGFloat radiusX = width * (0.17f + (progress * 0.23f));
    CGFloat radiusY = height * (0.13f + (progress * 0.17f));
    CGFloat amplitude = MIN(width, height) * (0.014f + (progress * 0.010f));
    NSUInteger pointCount = 56;

    UIBezierPath *path = [UIBezierPath bezierPath];
    for (NSUInteger point = 0; point <= pointCount; point += 1) {
        CGFloat angle = (((CGFloat)point) / ((CGFloat)pointCount)) * (CGFloat)(M_PI * 2.0);
        CGFloat wobbleA = sinf((angle * 2.0f) + phase) * amplitude;
        CGFloat wobbleB = cosf((angle * 3.0f) - (phase * 0.74f)) * amplitude * 0.54f;
        CGFloat wobbleC = sinf((angle * 5.0f) + (phase * 1.12f)) * amplitude * 0.20f;
        CGFloat x = centerX + (cosf(angle) * (radiusX + wobbleA + wobbleB));
        CGFloat y = centerY + (sinf(angle) * (radiusY + (wobbleA * 0.72f) - (wobbleB * 0.16f) + wobbleC));
        CGPoint p = CGPointMake(x, y);
        if (point == 0) {
            [path moveToPoint:p];
        } else {
            [path addLineToPoint:p];
        }
    }
    [path closePath];
    return path;
}

- (void)restartLinePathAnimationsPreservingCurrentState:(BOOL)preserveCurrentState {
    if (CGRectIsEmpty(self.bounds)) {
        return;
    }
    self.hasStartedAnimations = YES;

    CGFloat durationMultiplier = self.playing ? 1.0f : 1.28f;
    [self.lineLayers enumerateObjectsUsingBlock:^(CAShapeLayer * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [line removeAnimationForKey:@"sonora_wave_line_path"];
        [line removeAnimationForKey:@"sonora_wave_line_transition"];
        [line removeAnimationForKey:@"sonora_wave_line_width_transition"];

        UIBezierPath *path0 = [self contourPathForIndex:idx variant:0];
        UIBezierPath *path1 = [self contourPathForIndex:idx variant:1];
        UIBezierPath *path2 = [self contourPathForIndex:idx variant:2];
        CGPathRef startingPath = preserveCurrentState ? SonoraShapeLayerPresentationPath(line) : path0.CGPath;
        if (startingPath == NULL) {
            startingPath = path0.CGPath;
        }
        line.path = startingPath;

        CAKeyframeAnimation *pathAnim = [CAKeyframeAnimation animationWithKeyPath:@"path"];
        id loopReturnPath = preserveCurrentState ? (__bridge id)startingPath : (__bridge id)path0.CGPath;
        pathAnim.values = @[
            (__bridge id)startingPath,
            (__bridge id)path1.CGPath,
            (__bridge id)path2.CGPath,
            loopReturnPath
        ];
        pathAnim.keyTimes = @[@0.0, @0.34, @0.68, @1.0];
        pathAnim.duration = (8.4 + (((CGFloat)idx) * 0.85f)) * durationMultiplier;
        pathAnim.repeatCount = HUGE_VALF;
        pathAnim.calculationMode = kCAAnimationLinear;
        pathAnim.beginTime = CACurrentMediaTime() + (preserveCurrentState ? 0.0 : (((CGFloat)idx) * 0.08f));
        pathAnim.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
        ];
        [line addAnimation:pathAnim forKey:@"sonora_wave_line_path"];
    }];
}

- (void)restartLineEmphasisAnimationsPreservingCurrentState:(BOOL)preserveCurrentState {
    if (CGRectIsEmpty(self.bounds)) {
        return;
    }
    self.hasStartedAnimations = YES;

    CGFloat durationMultiplier = self.playing ? 1.0f : 1.28f;
    [self.lineLayers enumerateObjectsUsingBlock:^(CAShapeLayer * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        [line removeAnimationForKey:@"sonora_wave_line_scale"];
        [line removeAnimationForKey:@"sonora_wave_line_rotation"];
        [line removeAnimationForKey:@"sonora_wave_line_shadow"];
        [line removeAnimationForKey:@"sonora_wave_line_opacity"];

        CGFloat baseOpacity = self.playing
        ? (idx < 2 ? 0.96f : (idx < 4 ? 0.82f : 0.66f))
        : (idx < 2 ? 0.78f : (idx < 4 ? 0.64f : 0.52f));
        CGFloat swing = self.playing ? 0.16f : 0.10f;
        CGFloat currentOpacity = preserveCurrentState ? SonoraLayerPresentationFloat(line, @"opacity", line.opacity) : baseOpacity;
        CGFloat currentShadowOpacity = preserveCurrentState ? SonoraLayerPresentationFloat(line, @"shadowOpacity", line.shadowOpacity) : line.shadowOpacity;
        CGFloat currentScale = preserveCurrentState ? SonoraLayerPresentationFloat(line, @"transform.scale", 1.0f) : (0.998f - (((CGFloat)idx) * 0.0008f));
        CGFloat currentRotation = preserveCurrentState ? SonoraLayerPresentationFloat(line, @"transform.rotation.z", 0.0f) : 0.0f;
        line.opacity = currentOpacity;
        line.shadowOpacity = currentShadowOpacity;
        line.transform = SonoraWaveTransform(currentScale, currentRotation);

        CAKeyframeAnimation *opacityAnim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        NSNumber *loopReturnOpacity = preserveCurrentState ? @(currentOpacity) : @(baseOpacity - (swing * 0.35f));
        opacityAnim.values = @[
            @(currentOpacity),
            @(baseOpacity + swing),
            @(baseOpacity - (swing * 0.18f)),
            loopReturnOpacity
        ];
        opacityAnim.keyTimes = @[@0.0, @0.32, @0.70, @1.0];
        opacityAnim.duration = (4.8 + (((CGFloat)idx) * 0.50)) * durationMultiplier;
        opacityAnim.repeatCount = HUGE_VALF;
        opacityAnim.beginTime = CACurrentMediaTime() + (preserveCurrentState ? 0.0 : (((CGFloat)idx) * 0.08f));
        opacityAnim.timingFunctions = @[
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
            [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]
        ];
        [line addAnimation:opacityAnim forKey:@"sonora_wave_line_opacity"];

        if (self.playing) {
            CABasicAnimation *scaleAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            scaleAnim.fromValue = @(currentScale);
            scaleAnim.toValue = @(1.010f + (((CGFloat)idx) * 0.0012f));
            scaleAnim.duration = 7.4 + (((CGFloat)idx) * 0.70f);
            scaleAnim.autoreverses = YES;
            scaleAnim.repeatCount = HUGE_VALF;
            scaleAnim.beginTime = CACurrentMediaTime() + (preserveCurrentState ? 0.0 : (((CGFloat)idx) * 0.06f));
            scaleAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [line addAnimation:scaleAnim forKey:@"sonora_wave_line_scale"];

            CABasicAnimation *rotationAnim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            CGFloat rotation = 0.0016f + (((CGFloat)idx) * 0.0006f);
            rotationAnim.fromValue = @(currentRotation);
            rotationAnim.toValue = @(rotation);
            rotationAnim.duration = 12.2 + (((CGFloat)idx) * 0.80f);
            rotationAnim.autoreverses = YES;
            rotationAnim.repeatCount = HUGE_VALF;
            rotationAnim.beginTime = CACurrentMediaTime() + (preserveCurrentState ? 0.0 : (((CGFloat)idx) * 0.05f));
            rotationAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [line addAnimation:rotationAnim forKey:@"sonora_wave_line_rotation"];

            CABasicAnimation *shadowAnim = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
            shadowAnim.fromValue = @(currentShadowOpacity);
            shadowAnim.toValue = @(MIN(1.0f, line.shadowOpacity + 0.18f));
            shadowAnim.duration = 5.6 + (((CGFloat)idx) * 0.55f);
            shadowAnim.autoreverses = YES;
            shadowAnim.repeatCount = HUGE_VALF;
            shadowAnim.beginTime = CACurrentMediaTime() + (preserveCurrentState ? 0.0 : (((CGFloat)idx) * 0.04f));
            shadowAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [line addAnimation:shadowAnim forKey:@"sonora_wave_line_shadow"];
        }
    }];
}

- (void)restartLineAnimationsPreservingCurrentState:(BOOL)preserveCurrentState {
    [self restartLinePathAnimationsPreservingCurrentState:preserveCurrentState];
    [self restartLineEmphasisAnimationsPreservingCurrentState:preserveCurrentState];
}

- (void)restartLineAnimations {
    [self restartLineAnimationsPreservingCurrentState:NO];
}

- (void)restartGlowAnimationsPreservingCurrentState:(BOOL)preserveCurrentState {
    [self.haloLayer removeAnimationForKey:@"sonora_wave_halo_scale"];
    [self.haloLayer removeAnimationForKey:@"sonora_wave_halo_opacity"];
    [self.coreGlowLayer removeAnimationForKey:@"sonora_wave_core_scale"];
    [self.coreGlowLayer removeAnimationForKey:@"sonora_wave_core_opacity"];

    CGFloat currentHaloScale = preserveCurrentState ? SonoraLayerPresentationFloat(self.haloLayer, @"transform.scale", 1.0f) : (self.playing ? 0.96f : 0.985f);
    CGFloat currentCoreScale = preserveCurrentState ? SonoraLayerPresentationFloat(self.coreGlowLayer, @"transform.scale", 1.0f) : (self.playing ? 0.92f : 0.96f);
    CGFloat currentHaloOpacity = preserveCurrentState ? SonoraLayerPresentationFloat(self.haloLayer, @"opacity", self.haloLayer.opacity) : (self.playing ? 0.80f : 0.64f);
    CGFloat currentCoreOpacity = preserveCurrentState ? SonoraLayerPresentationFloat(self.coreGlowLayer, @"opacity", self.coreGlowLayer.opacity) : (self.playing ? 0.52f : 0.38f);
    self.haloLayer.transform = CATransform3DMakeScale(currentHaloScale, currentHaloScale, 1.0f);
    self.coreGlowLayer.transform = CATransform3DMakeScale(currentCoreScale, currentCoreScale, 1.0f);
    self.haloLayer.opacity = currentHaloOpacity;
    self.coreGlowLayer.opacity = currentCoreOpacity;

    CABasicAnimation *haloScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    haloScale.fromValue = @(currentHaloScale);
    haloScale.toValue = @(self.playing ? 1.08f : 1.03f);
    haloScale.duration = self.playing ? 4.2 : 6.0;
    haloScale.autoreverses = YES;
    haloScale.repeatCount = HUGE_VALF;
    haloScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.haloLayer addAnimation:haloScale forKey:@"sonora_wave_halo_scale"];

    CABasicAnimation *haloOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    haloOpacity.fromValue = @(currentHaloOpacity);
    haloOpacity.toValue = @(self.playing ? 1.0f : 0.82f);
    haloOpacity.duration = self.playing ? 3.6 : 5.4;
    haloOpacity.autoreverses = YES;
    haloOpacity.repeatCount = HUGE_VALF;
    haloOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.haloLayer addAnimation:haloOpacity forKey:@"sonora_wave_halo_opacity"];

    CABasicAnimation *coreScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    coreScale.fromValue = @(currentCoreScale);
    coreScale.toValue = @(self.playing ? 1.04f : 1.01f);
    coreScale.duration = self.playing ? 5.4 : 7.2;
    coreScale.autoreverses = YES;
    coreScale.repeatCount = HUGE_VALF;
    coreScale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.coreGlowLayer addAnimation:coreScale forKey:@"sonora_wave_core_scale"];

    CABasicAnimation *coreOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    coreOpacity.fromValue = @(currentCoreOpacity);
    coreOpacity.toValue = @(self.playing ? 0.82f : 0.58f);
    coreOpacity.duration = self.playing ? 4.8 : 6.6;
    coreOpacity.autoreverses = YES;
    coreOpacity.repeatCount = HUGE_VALF;
    coreOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.coreGlowLayer addAnimation:coreOpacity forKey:@"sonora_wave_core_opacity"];
}

- (void)restartGlowAnimations {
    [self restartGlowAnimationsPreservingCurrentState:NO];
}

- (void)restartAnimations {
    [self restartLineAnimations];
    [self restartGlowAnimations];
}

- (void)ensureAnimationsRunning {
    if (CGRectIsEmpty(self.bounds) || self.lineLayers.count == 0) {
        return;
    }

    [self restoreAnimationSnapshotIfNeeded];

    __block BOOL isMissingLinePathAnimations = NO;
    __block BOOL isMissingLineEmphasisAnimations = NO;
    [self.lineLayers enumerateObjectsUsingBlock:^(CAShapeLayer * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)idx;
        if ([line animationForKey:@"sonora_wave_line_path"] == nil) {
            isMissingLinePathAnimations = YES;
        }
        if ([line animationForKey:@"sonora_wave_line_opacity"] == nil ||
            (self.playing &&
             ([line animationForKey:@"sonora_wave_line_scale"] == nil ||
              [line animationForKey:@"sonora_wave_line_rotation"] == nil ||
              [line animationForKey:@"sonora_wave_line_shadow"] == nil))) {
            isMissingLineEmphasisAnimations = YES;
        }
        if (isMissingLinePathAnimations || isMissingLineEmphasisAnimations) {
            *stop = YES;
        }
    }];

    BOOL isMissingGlowAnimations =
    ([self.haloLayer animationForKey:@"sonora_wave_halo_scale"] == nil) ||
    ([self.haloLayer animationForKey:@"sonora_wave_halo_opacity"] == nil) ||
    ([self.coreGlowLayer animationForKey:@"sonora_wave_core_scale"] == nil) ||
    ([self.coreGlowLayer animationForKey:@"sonora_wave_core_opacity"] == nil);

    if (isMissingLinePathAnimations) {
        [self restartLinePathAnimationsPreservingCurrentState:YES];
    }
    if (isMissingLineEmphasisAnimations) {
        [self restartLineEmphasisAnimationsPreservingCurrentState:YES];
    }
    if (isMissingGlowAnimations) {
        [self restartGlowAnimationsPreservingCurrentState:YES];
    }
}

- (void)transitionToUpdatedGeometry {
    if (CGRectIsEmpty(self.bounds)) {
        return;
    }
    if (!self.hasStartedAnimations) {
        [self configureLineGeometry];
        return;
    }

    self.geometryTransitionGeneration += 1;
    NSUInteger generation = self.geometryTransitionGeneration;
    CGFloat duration = self.playing ? 1.02f : 1.16f;
    CGFloat scale = MAX(0.92f, MIN(1.20f, MIN(CGRectGetWidth(self.bounds) / 360.0f, CGRectGetHeight(self.bounds) / 220.0f)));
    NSArray<NSNumber *> *lineWidths = @[
        @(2.8f * scale),
        @(2.5f * scale),
        @(2.2f * scale),
        @(1.9f * scale),
        @(1.7f * scale),
        @(1.5f * scale),
        @(1.2f * scale)
    ];

    [self.lineLayers enumerateObjectsUsingBlock:^(CAShapeLayer * _Nonnull line, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        UIBezierPath *targetPath = [self contourPathForIndex:idx variant:0];
        CGPathRef currentPath = ((CAShapeLayer *)line.presentationLayer).path ?: line.path;
        CGFloat currentWidth = ((CAShapeLayer *)line.presentationLayer).lineWidth > 0.0f
        ? ((CAShapeLayer *)line.presentationLayer).lineWidth
        : line.lineWidth;
        CGFloat targetWidth = lineWidths[idx].doubleValue;

        [line removeAnimationForKey:@"sonora_wave_line_path"];
        [line removeAnimationForKey:@"sonora_wave_line_transition"];
        [line removeAnimationForKey:@"sonora_wave_line_width_transition"];

        if (currentPath != NULL) {
            CABasicAnimation *pathTransition = [CABasicAnimation animationWithKeyPath:@"path"];
            pathTransition.fromValue = (__bridge id)currentPath;
            pathTransition.toValue = (__bridge id)targetPath.CGPath;
            pathTransition.duration = duration;
            pathTransition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [line addAnimation:pathTransition forKey:@"sonora_wave_line_transition"];
        }

        CABasicAnimation *widthTransition = [CABasicAnimation animationWithKeyPath:@"lineWidth"];
        widthTransition.fromValue = @(currentWidth);
        widthTransition.toValue = @(targetWidth);
        widthTransition.duration = duration;
        widthTransition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [line addAnimation:widthTransition forKey:@"sonora_wave_line_width_transition"];

        line.lineWidth = targetWidth;
        line.path = targetPath.CGPath;
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((duration + 0.04f) * (CGFloat)NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.geometryTransitionGeneration != generation) {
            return;
        }
        [self restartLinePathAnimationsPreservingCurrentState:YES];
    });
}

- (void)updatePlaybackStateAnimated:(BOOL)animated {
    CGFloat haloOpacity = self.playing ? 0.94f : 0.78f;
    CGFloat coreOpacity = self.playing ? 0.74f : 0.50f;
    CGFloat lineOpacity = self.playing ? 1.0f : 0.92f;
    if (animated) {
        CABasicAnimation *haloAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
        haloAnim.fromValue = @(self.haloLayer.opacity);
        haloAnim.toValue = @(haloOpacity);
        haloAnim.duration = 0.28;
        [self.haloLayer addAnimation:haloAnim forKey:@"sonora_wave_state_halo_opacity"];

        CABasicAnimation *containerAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
        containerAnim.fromValue = @(self.lineContainerLayer.opacity);
        containerAnim.toValue = @(lineOpacity);
        containerAnim.duration = 0.28;
        [self.lineContainerLayer addAnimation:containerAnim forKey:@"sonora_wave_state_line_opacity"];

        CABasicAnimation *coreAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
        coreAnim.fromValue = @(self.coreGlowLayer.opacity);
        coreAnim.toValue = @(coreOpacity);
        coreAnim.duration = 0.28;
        [self.coreGlowLayer addAnimation:coreAnim forKey:@"sonora_wave_state_core_opacity"];
    }
    self.haloLayer.opacity = haloOpacity;
    self.coreGlowLayer.opacity = coreOpacity;
    self.lineContainerLayer.opacity = lineOpacity;
}

@end



@interface SonoraWaveNebulaBackgroundView ()

@property (nonatomic, strong) CAGradientLayer *baseGradientLayer;
@property (nonatomic, strong) CALayer *blobContainerLayer;
@property (nonatomic, strong) NSArray<CAGradientLayer *> *blobLayers;
@property (nonatomic, strong) CAGradientLayer *cloudMaskLayer;
@property (nonatomic, strong) CAGradientLayer *pulseLayer;
@property (nonatomic, strong) CAGradientLayer *vignetteLayer;
@property (nonatomic, strong) UIImageView *grainView;
@property (nonatomic, strong, nullable) CADisplayLink *displayLink;
@property (nonatomic, assign) BOOL hasStartedAnimations;
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) CGFloat pulseSeed;
@property (nonatomic, assign) CFTimeInterval phaseStartTime;

@end

@implementation SonoraWaveNebulaBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.pulseSeed = 0.43f;
        self.phaseStartTime = CACurrentMediaTime();
        [self setupUI];
    }
    return self;
}

- (void)dealloc {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)setupUI {
    self.clipsToBounds = YES;

    CAGradientLayer *base = [CAGradientLayer layer];
    base.startPoint = CGPointMake(0.0, 0.0);
    base.endPoint = CGPointMake(1.0, 1.0);
    base.colors = @[
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)[UIColor clearColor].CGColor
    ];
    [self.layer addSublayer:base];
    self.baseGradientLayer = base;

    CALayer *blobContainer = [CALayer layer];
    [self.layer addSublayer:blobContainer];
    self.blobContainerLayer = blobContainer;

    CAGradientLayer *cloudMask = [CAGradientLayer layer];
    cloudMask.type = kCAGradientLayerRadial;
    cloudMask.startPoint = CGPointMake(0.5, 0.5);
    cloudMask.endPoint = CGPointMake(1.0, 1.0);
    cloudMask.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.78].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    cloudMask.locations = @[@0.0, @0.72, @1.0];
    blobContainer.mask = cloudMask;
    self.cloudMaskLayer = cloudMask;

    NSMutableArray<CAGradientLayer *> *blobs = [NSMutableArray arrayWithCapacity:7];
    for (NSUInteger idx = 0; idx < 7; idx += 1) {
        CAGradientLayer *blob = [CAGradientLayer layer];
        blob.type = kCAGradientLayerRadial;
        blob.startPoint = CGPointMake(0.5, 0.5);
        blob.endPoint = CGPointMake(1.0, 1.0);
        blob.colors = @[
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.38].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.13].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        blob.locations = @[@0.0, @0.54, @1.0];
        blob.opacity = 1.0;
        [blobContainer addSublayer:blob];
        [blobs addObject:blob];
    }
    self.blobLayers = [blobs copy];

    CAGradientLayer *pulse = [CAGradientLayer layer];
    pulse.type = kCAGradientLayerRadial;
    pulse.startPoint = CGPointMake(0.5, 0.5);
    pulse.endPoint = CGPointMake(1.0, 1.0);
    pulse.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.14].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    pulse.locations = @[@0.0, @1.0];
    pulse.opacity = 0.16;
    [self.layer addSublayer:pulse];
    self.pulseLayer = pulse;

    CAGradientLayer *vignette = [CAGradientLayer layer];
    vignette.type = kCAGradientLayerRadial;
    vignette.startPoint = CGPointMake(0.5, 0.5);
    vignette.endPoint = CGPointMake(1.0, 1.0);
    vignette.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    [self.layer addSublayer:vignette];
    self.vignetteLayer = vignette;

    UIImageView *grainView = [[UIImageView alloc] init];
    grainView.translatesAutoresizingMaskIntoConstraints = NO;
    grainView.userInteractionEnabled = NO;
    grainView.alpha = 0.10;
    grainView.image = [self grainImage];
    grainView.contentMode = UIViewContentModeScaleToFill;
    self.grainView = grainView;
    [self addSubview:grainView];

    [NSLayoutConstraint activateConstraints:@[
        [grainView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [grainView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [grainView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [grainView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

- (UIImage *)grainImage {
    const size_t width = 96;
    const size_t height = 96;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL) {
        return [UIImage new];
    }

    for (NSUInteger y = 0; y < height; y += 1) {
        for (NSUInteger x = 0; x < width; x += 1) {
            CGFloat value = ((CGFloat)arc4random_uniform(1000)) / 1000.0;
            CGFloat alpha = 0.01 + (value * 0.04);
            UIColor *color = (value > 0.5)
            ? [UIColor colorWithWhite:1.0 alpha:alpha]
            : [UIColor colorWithWhite:0.0 alpha:alpha * 0.8];
            CGContextSetFillColorWithColor(context, color.CGColor);
            CGContextFillRect(context, CGRectMake(x, y, 1.0, 1.0));
        }
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.baseGradientLayer.frame = self.bounds;
    self.blobContainerLayer.frame = self.bounds;
    self.cloudMaskLayer.frame = self.bounds;
    self.pulseLayer.frame = self.bounds;
    self.vignetteLayer.frame = self.bounds;

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);
    CGFloat minSide = MIN(w, h);
    NSArray<NSValue *> *centers = @[
        [NSValue valueWithCGPoint:CGPointMake(w * 0.37, h * 0.43)],
        [NSValue valueWithCGPoint:CGPointMake(w * 0.63, h * 0.42)],
        [NSValue valueWithCGPoint:CGPointMake(w * 0.50, h * 0.56)],
        [NSValue valueWithCGPoint:CGPointMake(w * 0.34, h * 0.58)],
        [NSValue valueWithCGPoint:CGPointMake(w * 0.66, h * 0.57)],
        [NSValue valueWithCGPoint:CGPointMake(w * 0.48, h * 0.32)],
        [NSValue valueWithCGPoint:CGPointMake(w * 0.52, h * 0.70)]
    ];
    NSArray<NSNumber *> *sizes = @[
        @(MAX(minSide * 0.72, 160.0)),
        @(MAX(minSide * 0.68, 152.0)),
        @(MAX(minSide * 0.80, 178.0)),
        @(MAX(minSide * 0.60, 138.0)),
        @(MAX(minSide * 0.58, 132.0)),
        @(MAX(minSide * 0.54, 124.0)),
        @(MAX(minSide * 0.52, 120.0))
    ];

    [self.blobLayers enumerateObjectsUsingBlock:^(CAGradientLayer * _Nonnull layer, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        CGFloat size = sizes[idx].doubleValue;
        CGPoint center = centers[idx].CGPointValue;
        layer.bounds = CGRectMake(0.0, 0.0, size, size);
        layer.position = center;
    }];

    [self startAnimationsIfNeeded];
}

- (void)startAnimationsIfNeeded {
    if (self.hasStartedAnimations) {
        return;
    }
    self.hasStartedAnimations = YES;

    NSArray<NSNumber *> *durations = @[@(10.8), @(9.6), @(11.8), @(8.6), @(12.6), @(9.0), @(10.2)];
    [self.blobLayers enumerateObjectsUsingBlock:^(CAGradientLayer * _Nonnull layer, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        scale.fromValue = @(0.96);
        scale.toValue = @(1.04);
        scale.duration = durations[idx].doubleValue;
        scale.autoreverses = YES;
        scale.repeatCount = HUGE_VALF;
        scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [layer addAnimation:scale forKey:[NSString stringWithFormat:@"sonora_wave_scale_%lu", (unsigned long)idx]];

        CABasicAnimation *position = [CABasicAnimation animationWithKeyPath:@"position"];
        CGPoint p = layer.position;
        CGFloat shiftX = 8.0 + ((CGFloat)idx * 2.0);
        CGFloat shiftY = 6.0 + ((CGFloat)(idx % 3) * 2.0);
        position.fromValue = [NSValue valueWithCGPoint:CGPointMake(p.x - shiftX, p.y + shiftY)];
        position.toValue = [NSValue valueWithCGPoint:CGPointMake(p.x + shiftX, p.y - shiftY)];
        position.duration = durations[idx].doubleValue + 1.2;
        position.autoreverses = YES;
        position.repeatCount = HUGE_VALF;
        position.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [layer addAnimation:position forKey:[NSString stringWithFormat:@"sonora_wave_position_%lu", (unsigned long)idx]];
    }];
    [self startDisplayLinkIfNeeded];
}

- (void)startDisplayLinkIfNeeded {
    if (self.displayLink != nil) {
        return;
    }
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayLinkTick:)];
    [link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    self.displayLink = link;
    self.phaseStartTime = CACurrentMediaTime();
}

- (void)handleDisplayLinkTick:(CADisplayLink *)link {
    (void)link;
    CFTimeInterval elapsed = CACurrentMediaTime() - self.phaseStartTime;
    CGFloat t = (CGFloat)elapsed;

    CGFloat ambient = 0.5f + (0.5f * sinf((t * 0.52f) + (self.pulseSeed * 6.28318f)));
    CGFloat drift = 0.5f + (0.5f * cosf((t * 0.38f) + (self.pulseSeed * 4.398f)));

    CGFloat audioImpulse = 0.0f;
    if (self.playing) {
        SonoraPlaybackManager *playback = SonoraPlaybackManager.sharedManager;
        CGFloat position = (CGFloat)MAX(0.0, playback.currentTime);
        CGFloat duration = (CGFloat)MAX(1.0, playback.duration);
        CGFloat bpm = 92.0f + fmodf((self.pulseSeed * 71.0f) + duration, 46.0f);
        CGFloat beatPhase = position * (bpm / 60.0f) * 6.28318f;
        CGFloat primary = powf(MAX(0.0f, sinf(beatPhase)), 2.8f);
        CGFloat secondary = powf(MAX(0.0f, sinf((beatPhase * 0.5f) + 0.75f)), 4.0f) * 0.42f;
        audioImpulse = MIN(1.0f, primary + secondary);
    }

    CGFloat pulseOpacity = 0.10f + (ambient * 0.08f) + (audioImpulse * 0.30f);
    self.pulseLayer.opacity = pulseOpacity;
    CGFloat pulseScale = 0.96f + (drift * 0.03f) + (audioImpulse * 0.11f);
    self.pulseLayer.transform = CATransform3DMakeScale(pulseScale, pulseScale, 1.0f);

    [self.blobLayers enumerateObjectsUsingBlock:^(CAGradientLayer * _Nonnull layer, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        CGFloat idxBoost = MAX(0.07f, 0.20f - (((CGFloat)idx) * 0.017f));
        layer.opacity = 0.82f + (ambient * 0.08f) + (audioImpulse * idxBoost);
    }];
}

- (void)setPlaying:(BOOL)playing {
    _playing = playing;
}

- (void)setPulseSeedWithTrackIdentifier:(NSString * _Nullable)identifier {
    const char *utf8 = identifier.UTF8String;
    if (utf8 == NULL || utf8[0] == '\0') {
        self.pulseSeed = 0.43f;
        self.phaseStartTime = CACurrentMediaTime();
        return;
    }

    uint64_t hash = 1469598103934665603ULL;
    const uint8_t *bytes = (const uint8_t *)utf8;
    while (*bytes != 0) {
        hash ^= (uint64_t)(*bytes);
        hash *= 1099511628211ULL;
        bytes += 1;
    }
    self.pulseSeed = (CGFloat)((hash % 1000ULL) / 1000.0);
    self.phaseStartTime = CACurrentMediaTime();
}

- (void)applyPalette:(NSArray<UIColor *> *)palette animated:(BOOL)animated {
    NSArray<UIColor *> *resolved = (palette.count >= 4) ? palette : SonoraResolvedWavePalette(nil);

    NSArray *baseColors = @[
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)[UIColor clearColor].CGColor
    ];
    if (animated) {
        CABasicAnimation *baseAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        baseAnim.fromValue = self.baseGradientLayer.colors;
        baseAnim.toValue = baseColors;
        baseAnim.duration = 2.0;
        baseAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.baseGradientLayer addAnimation:baseAnim forKey:@"sonora_wave_base_colors"];
    }
    self.baseGradientLayer.colors = baseColors;

    UIColor *pulseColor = SonoraBlendColor(resolved[3], UIColor.whiteColor, 0.26);
    NSArray *pulseColors = @[
        (__bridge id)[pulseColor colorWithAlphaComponent:0.20].CGColor,
        (__bridge id)[pulseColor colorWithAlphaComponent:0.0].CGColor
    ];
    if (animated) {
        CABasicAnimation *pulseAnim = [CABasicAnimation animationWithKeyPath:@"colors"];
        pulseAnim.fromValue = self.pulseLayer.colors;
        pulseAnim.toValue = pulseColors;
        pulseAnim.duration = 2.0;
        pulseAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self.pulseLayer addAnimation:pulseAnim forKey:@"sonora_wave_pulse_colors"];
    }
    self.pulseLayer.colors = pulseColors;

    NSArray<UIColor *> *blobColors = @[
        resolved[1],
        resolved[2],
        resolved[3],
        resolved[0],
        resolved[2],
        resolved[3],
        resolved[1]
    ];
    [self.blobLayers enumerateObjectsUsingBlock:^(CAGradientLayer * _Nonnull layer, NSUInteger idx, BOOL * _Nonnull stop) {
        (void)stop;
        UIColor *color = blobColors[idx];
        NSArray *colors = @[
            (__bridge id)[color colorWithAlphaComponent:0.38].CGColor,
            (__bridge id)[color colorWithAlphaComponent:0.13].CGColor,
            (__bridge id)[color colorWithAlphaComponent:0.0].CGColor
        ];
        if (animated) {
            CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"colors"];
            anim.fromValue = layer.colors;
            anim.toValue = colors;
            anim.duration = 1.8;
            anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [layer addAnimation:anim forKey:[NSString stringWithFormat:@"sonora_wave_blob_colors_%lu", (unsigned long)idx]];
        }
        layer.colors = colors;
    }];
}

@end
