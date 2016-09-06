#import "UIColor+TCUtilities.h"

#define MAKEBYTE(_VALUE_) (int)(_VALUE_ * 0xFF) & 0xFF

NS_INLINE CGFloat cgfmin(CGFloat a, CGFloat b) { return (a < b) ? a : b;}
NS_INLINE CGFloat cgfmax(CGFloat a, CGFloat b) { return (a > b) ? a : b;}
NS_INLINE CGFloat cgfunitclamp(CGFloat f) {return cgfmax(0.0, cgfmin(1.0, f));}

CGColorSpaceRef tcDeviceRGBSpace(void)
{
    static CGColorSpaceRef rgbSpace = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rgbSpace = CGColorSpaceCreateDeviceRGB();
    });
    return rgbSpace;
}

CGColorSpaceRef tcDeviceGraySpace(void)
{
    static CGColorSpaceRef graySpace = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        graySpace = CGColorSpaceCreateDeviceGray();
    });
    return graySpace;
}

UIColor *tcRandomColor(void)
{
    static BOOL seeded = NO;
    if (!seeded) {
        seeded = YES;
        srandom((unsigned)time(NULL));
    }
    return [UIColor colorWithRed:random() / (CGFloat) LONG_MAX
                           green:random() / (CGFloat) LONG_MAX
                            blue:random() / (CGFloat) LONG_MAX
                           alpha:1.0f];
}

UIColor *tcInterpolateColors(UIColor *c1, UIColor *c2, CGFloat amt)
{
    CGFloat r = (c2.red * amt) + (c1.red * (1.0f - amt));
    CGFloat g = (c2.green * amt) + (c1.green * (1.0f - amt));
    CGFloat b = (c2.blue * amt) + (c1.blue * (1.0f - amt));
    CGFloat a = (c2.alpha * amt) + (c1.alpha * (1.0f - amt));
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

@implementation UIColor (TCUtilities)

// Generate a color wheel. You supply the size, e.g.
// UIImage *image = [UIColor colorWheelOfSize:500];

+ (UIImage *)colorWheelOfSize:(CGFloat)side border:(BOOL)useBorder
{
    UIBezierPath *path = nil;
    CGSize size = CGSizeMake(side, side);
    CGPoint center = CGPointMake(side / 2, side / 2);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    for (NSInteger i = 0; i < 6; ++i) {
        CGFloat width = side / 14;
        CGFloat radius = width * (i + 1.0f);
        CGFloat saturation = (i + 1.0f) / 6.0f;
        
        for (CGFloat theta = 0; theta < M_PI * 2; theta += (M_PI / 6)) {
            CGFloat hue = (CGFloat)(theta / (2 * M_PI));
            UIColor *c = [UIColor colorWithHue:hue saturation:saturation brightness:1 alpha:1.0f];
            
            CGFloat angle = (CGFloat)(theta - M_PI_2);
            if (angle < 0) {
                angle += 2 * M_PI;
            }
            
            path = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:angle endAngle:(CGFloat)(angle + M_PI / 6) clockwise:YES];
            path.lineWidth = width;
            
            [c set];
            [path stroke];
        }
    }
    
    if (useBorder) {
        [[UIColor blackColor] set];
        path = [UIBezierPath bezierPathWithArcCenter:center radius:(side / 2) - (side / 28) startAngle:0 endAngle:(CGFloat)(2 * M_PI) clockwise:YES];
        path.lineWidth = 4;
        [path stroke];
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - Color Space

// Report model
- (CGColorSpaceModel)colorSpaceModel
{
    return CGColorSpaceGetModel(CGColorGetColorSpace(self.CGColor));
}

// Represent model as string
+ (NSString *)colorSpaceString:(CGColorSpaceModel)model
{
    switch (model) {
        case kCGColorSpaceModelUnknown:
            return @"kCGColorSpaceModelUnknown";
        case kCGColorSpaceModelMonochrome:
            return @"kCGColorSpaceModelMonochrome";
        case kCGColorSpaceModelRGB:
            return @"kCGColorSpaceModelRGB";
        case kCGColorSpaceModelCMYK:
            return @"kCGColorSpaceModelCMYK";
        case kCGColorSpaceModelLab:
            return @"kCGColorSpaceModelLab";
        case kCGColorSpaceModelDeviceN:
            return @"kCGColorSpaceModelDeviceN";
        case kCGColorSpaceModelIndexed:
            return @"kCGColorSpaceModelIndexed";
        case kCGColorSpaceModelPattern:
            return @"kCGColorSpaceModelPattern";
        default:
            return @"Not a valid color space";
    }
}

// Report color space as string
- (NSString *)colorSpaceString
{
    return [UIColor colorSpaceString:self.colorSpaceModel];
}

// Supports either RGB or W
- (BOOL)canProvideRGBComponents
{
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
        case kCGColorSpaceModelMonochrome:
            return YES;
        default:
            return NO;
    }
}

// Convenience: Test for Monochrome
- (BOOL)usesMonochromeColorspace
{
    return (self.colorSpaceModel == kCGColorSpaceModelMonochrome);
}

// Convenience: Test for RGB
- (BOOL)usesRGBColorspace
{
    return (self.colorSpaceModel == kCGColorSpaceModelRGB);
}

#pragma mark - CMYK Utility

+ (UIColor *)colorWithCyan:(CGFloat)c magenta:(CGFloat)m yellow:(CGFloat)y black:(CGFloat)k
{
    CGFloat r = (1.0f - c) * (1.0f - k);
    CGFloat g = (1.0f - m) * (1.0f - k);
    CGFloat b = (1.0f - y) * (1.0f - k);
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0f];
}

- (void)toC:(CGFloat *)cyan toM:(CGFloat *)magenta toY:(CGFloat *)yellow toK:(CGFloat *)black
{
    CGFloat r = self.red;
    CGFloat g = self.green;
    CGFloat b = self.blue;
    
    CGFloat k = (CGFloat)(1.0f - fmax(fmax(r, g), b));
    CGFloat dK = 1.0f - k;
    
    CGFloat c = (1.0f - (r + k)) / dK;
    CGFloat m = (1.0f - (g + k)) / dK;
    CGFloat y = (1.0f - (b + k)) / dK;
    
    if (NULL != cyan) {
        *cyan = c;
    }
    if (NULL != magenta) {
        *magenta = m;
    }
    if (NULL != yellow) {
        *yellow = y;
    }
    if (NULL != black) {
        *black = k;
    }
}

- (CGFloat)cyanChannel
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -cyanChannel");
    CGFloat c = 0.0f;
    [self toC:&c toM:NULL toY:NULL toK:NULL];
    return c;
}

- (CGFloat)magentaChannel
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -magentaChannel");
    CGFloat m = 0.0f;
    [self toC:NULL toM:&m toY:NULL toK:NULL];
    return m;
}

- (CGFloat)yellowChannel
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -yellowChannel");
    CGFloat y = 0.0f;
    [self toC:NULL toM:NULL toY:&y toK:NULL];
    return y;
}

- (CGFloat)blackChannel
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -blackChannel");
    CGFloat k = 0.0f;
    [self toC:NULL toM:NULL toY:NULL toK:&k];
    return k;
}

- (NSArray *)cmyk
{
    CGFloat c = 0.0f;
    CGFloat m = 0.0f;
    CGFloat y = 0.0f;
    CGFloat k = 0.0f;
    [self toC:&c toM:&m toY:&y toK:&k];
    return @[@(c), @(m), @(y), @(k)];
}

#pragma mark - Color Conversion

// I know. This could probably be just as easily done by
// creating a color and pulling out the components.
// Live, learn.

+ (void)hue:(CGFloat)h
 saturation:(CGFloat)s
 brightness:(CGFloat)v
      toRed:(CGFloat *)pR
      green:(CGFloat *)pG
       blue:(CGFloat *)pB
{
    CGFloat r = 0, g = 0, b = 0;
    
    // From Foley and Van Dam
    
    if (s == 0.0f) {
        // Achromatic color: there is no hue
        r = g = b = v;
    } else {
        // Chromatic color: there is a hue
        if (h == 360.0f) {
            h = 0.0f;
        }
        h /= 60.0f;                                        // h is now in [0, 6)
        
        CGFloat i = (CGFloat)floor(h);                              // largest integer <= h
        CGFloat f = h - i;                                // fractional part of h
        CGFloat p = v * (1 - s);
        CGFloat q = v * (1 - (s * f));
        CGFloat t = v * (1 - (s * (1 - f)));
        
        switch ((int)i) {
            case 0: r = v; g = t; b = p; break;
            case 1: r = q; g = v; b = p; break;
            case 2: r = p; g = v; b = t; break;
            case 3: r = p; g = q; b = v; break;
            case 4: r = t; g = p; b = v; break;
            case 5: r = v; g = p; b = q; break;
            default: break;
        }
    }
    
    if (NULL != pR) {
        *pR = r;
    }
    if (NULL != pG) {
        *pG = g;
    }
    if (NULL != pB) {
        *pB = b;
    }
}

+ (void)red:(CGFloat)r
      green:(CGFloat)g
       blue:(CGFloat)b
      toHue:(CGFloat *)pH
 saturation:(CGFloat *)pS
 brightness:(CGFloat *)pV
{
    CGFloat h = 0, s = 0, v = 0;
    
    // From Foley and Van Dam
    
    CGFloat max = cgfmax(r, cgfmax(g, b));
    CGFloat min = cgfmin(r, cgfmin(g, b));
    
    // Brightness
    v = max;
    
    // Saturation
    s = (max != 0.0f) ? ((max - min) / max) : 0.0f;
    
    if (s == 0.0f) {
        // No saturation, so undefined hue
        h = 0.0f;
    } else {
        // Determine hue
        CGFloat rc = (max - r) / (max - min);        // Distance of color from red
        CGFloat gc = (max - g) / (max - min);        // Distance of color from green
        CGFloat bc = (max - b) / (max - min);        // Distance of color from blue
        
        if (r == max) {
            h = bc - gc;                    // resulting color between yellow and magenta
        } else if (g == max) {
            h = 2 + rc - bc;            // resulting color between cyan and yellow
        } else { /* if (b == max) */
            h = 4 + gc - rc;    // resulting color between magenta and cyan
        }
        
        h *= 60.0f;                                    // Convert to degrees
        if (h < 0.0f) {
            h += 360.0f;                    // Make non-negative
        }
    }
    
    if (NULL != pH) {
        *pH = h;
    }
    if (NULL != pS) {
        *pS = s;
    }
    if (NULL != pV) {
        *pV = v;
    }
}

void tcRGB2YUV_f(CGFloat r, CGFloat g, CGFloat b, CGFloat *y, CGFloat *u, CGFloat *v)
{
    if (NULL != y) {
        *y = (0.299f * r + 0.587f * g + 0.114f * b);
    }
    if (NULL != u && NULL != y) {
        *u = ((b - *y) * 0.565f + 0.5f);
    }
    if (NULL != v && NULL != y) {
        *v = ((r - *y) * 0.713f + 0.5f);
    }
    
    if (NULL != y) {
        *y = cgfunitclamp(*y);
    }
    if (NULL != u) {
        *u = cgfunitclamp(*u);
    }
    if (NULL != v) {
        *v = cgfunitclamp(*v);
    }
}

void tcYUV2RGB_f(CGFloat y, CGFloat u, CGFloat v, CGFloat *r, CGFloat *g, CGFloat *b)
{
    CGFloat Y = y;
    CGFloat U = u - 0.5f;
    CGFloat V = v - 0.5f;
    
    if (NULL != r) {
        *r = cgfunitclamp(Y + 1.403f * V);
    }
    if (NULL != g) {
        *g = cgfunitclamp(Y - 0.344f * U - 0.714f * V);
    }
    if (NULL != b) {
        *b = cgfunitclamp(Y + 1.770f * U);
    }
}

#pragma mark - Component Properties

- (CGFloat)red
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -red");
    CGFloat r = 0.0f;
    
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            [self getRed:&r green:NULL blue:NULL alpha:NULL];
            break;
        case kCGColorSpaceModelMonochrome:
            [self getWhite:&r alpha:NULL];
            break;
        default:
            break;
    }
    
    return r;
}

- (CGFloat)green
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -green");
    CGFloat g = 0.0f;
    
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            [self getRed:NULL green:&g blue:NULL alpha:NULL];
            break;
        case kCGColorSpaceModelMonochrome:
            [self getWhite:&g alpha:NULL];
            break;
        default:
            break;
    }
    
    return g;
}

- (CGFloat)blue
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -blue");
    CGFloat b = 0.0f;
    
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            [self getRed:NULL green:NULL blue:&b alpha:NULL];
            break;
        case kCGColorSpaceModelMonochrome:
            [self getWhite:&b alpha:NULL];
            break;
        default:
            break;
    }
    
    return b;
}

- (CGFloat)alpha
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -alpha");
    CGFloat a = 0.0f;
    
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            [self getRed:NULL green:NULL blue:NULL alpha:&a];
            break;
        case kCGColorSpaceModelMonochrome:
            [self getWhite:NULL alpha:&a];
            break;
        default:
            break;
    }
    
    return a;
}

- (CGFloat)white
{
    NSAssert(self.usesMonochromeColorspace, @"Must be a Monochrome color to use -white");
    
    CGFloat w = 0;
    [self getWhite:&w alpha:NULL];
    return w;
}


- (CGFloat)hue
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -hue");
    CGFloat h = 0.0f;
    
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            [self getHue:&h saturation:NULL brightness:NULL alpha:NULL];
            break;
        case kCGColorSpaceModelMonochrome:
            [self getWhite:&h alpha:NULL];
            break;
        default:
            break;
    }
    
    return h;
}

- (CGFloat)saturation
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -saturation");
    CGFloat s = 0.0f;
    
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            [self getHue:NULL saturation:&s brightness:NULL alpha:NULL];
            break;
        case kCGColorSpaceModelMonochrome:
            [self getWhite:&s alpha:NULL];
            break;
        default:
            break;
    }
    
    return s;
}

- (CGFloat)brightness
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -brightness");
    CGFloat v = 0.0f;
    
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            [self getHue:NULL saturation:NULL brightness:&v alpha:NULL];
            break;
        case kCGColorSpaceModelMonochrome:
            [self getWhite:&v alpha:NULL];
            break;
        default:
            break;
    }
    
    return v;
}

- (CGFloat)luminance
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use -luminance");
    
    CGFloat r = 0, g = 0, b = 0;
    if (![self getRed:&r green:&g blue:&b alpha:NULL]) {
        return 0.0f;
    }
    
    // http://en.wikipedia.org/wiki/Luma_(video)
    // Y = 0.2126 R + 0.7152 G + 0.0722 B
    return r * 0.2126f + g * 0.7152f + b * 0.0722f;
}

- (CGFloat)premultipliedRed { return self.red * self.alpha; }
- (CGFloat)premultipliedGreen { return self.green * self.alpha; }
- (CGFloat)premultipliedBlue {return self.blue * self.alpha; }

- (Byte)redByte { return MAKEBYTE(self.red); }
- (Byte)greenByte { return MAKEBYTE(self.green); }
- (Byte)blueByte { return MAKEBYTE(self.blue); }
- (Byte)alphaByte { return MAKEBYTE(self.alpha); }
- (Byte)whiteByte { return MAKEBYTE(self.white); };

- (NSData *)colorBytes
{
    Byte bytes[4] = {self.alphaByte, self.redByte, self.greenByte, self.blueByte};
    return [NSData dataWithBytes:bytes length:sizeof(bytes)/sizeof(bytes[0])];
}

- (NSData *)premultipledColorBytes
{
    Byte bytes[4] = {MAKEBYTE(self.alpha), MAKEBYTE(self.premultipliedRed), MAKEBYTE(self.premultipliedGreen), MAKEBYTE(self.premultipliedBlue)};
    return [NSData dataWithBytes:bytes length:sizeof(bytes)/sizeof(bytes[0])];
}

- (NSArray *)arrayFromRGBAComponents
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -arrayFromRGBAComponents");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    return @[@(r), @(g), @(b), @(a)];
}

#pragma mark - Gray Scale representation

- (instancetype)colorByLuminanceMapping
{
    return [UIColor colorWithWhite:self.luminance alpha:self.alpha];
}

#pragma mark - Alternative Expression

// Grays return 0. Fully saturated return 1
- (CGFloat)colorfulness
{
    CGFloat d1 = ABS(self.red - self.green);
    CGFloat d2 = ABS(self.green - self.blue);
    CGFloat d3 = ABS(self.blue - self.red);
    CGFloat sum = d1 + d2 + d3;
    
    sum *= 0.5f; // Max for fully saturated colors like green, red, cyan, magenta
    
    return sum;
}

#define WARMTH_OFFSET   (2.0f / 12.0f)

// Ranges from 0..1, cold (BLUE) to hot (YELLOW)
// Obviously, this isn't a standard "heat" map. I picked blue as my coldest
// color and adjusted the warmth value around that. Yellow is 180 degrees off
// from blue. If you want red as hot, use a zero offset but "cold" goes to aqua.
// You can do a lot more math (exercise left for reader) and squeeze
// blue to red and expand orange to whatever that blue color is between
// aqua and blue.
- (CGFloat)warmth
{
    CGFloat adjustment = WARMTH_OFFSET;
    CGFloat hue = self.hue - adjustment;
    if (hue > 0.5f) {
        hue -= 1.0f;
    }
    
    CGFloat distance = ABS(hue);
    return (0.5f - distance) * 2.0f;
}

// Return warmer version
- (instancetype)adjustWarmth:(CGFloat)delta
{
    CGFloat hue = self.hue - WARMTH_OFFSET;
    if (hue < 0) {
        hue += 1;
    }
    
    if (hue < 0.5f) {
        hue += delta;
    } else {
        hue -= delta;
    }
    
    hue = cgfmax(0.0, hue);
    hue = hue < 0.5f ? cgfmin(0.5f, hue) : cgfmax(0.5f, hue);
    
    hue += WARMTH_OFFSET;
    if (hue > 1.0f) {
        hue -= 1.0f;
    }
    
    return [UIColor colorWithHue:hue saturation:self.saturation brightness:self.brightness alpha:self.alpha];
}

// Return brighter version (if possible)
- (instancetype)adjustBrightness:(CGFloat)delta
{
    CGFloat b = self.brightness;
    b += delta;
    b = cgfunitclamp(b);
    
    return [UIColor colorWithHue:self.hue saturation:self.saturation brightness:b alpha:self.alpha];
}

// Return more saturated
- (instancetype)adjustSaturation:(CGFloat)delta
{
    CGFloat s = self.saturation;
    s += delta;
    s = cgfunitclamp(s);
    
    return [UIColor colorWithHue:self.hue saturation:s brightness:self.brightness alpha:self.alpha];
}

- (instancetype)adjustHue:(CGFloat)delta
{
    CGFloat h = self.hue + delta;
    
    // limit to 0..1
    while (h < 0.0f) {
        h += 1.0f;
    }
    while (h > 1.0f) {
        h -= 1.0f;
    }
    
    return [UIColor colorWithHue:h saturation:self.saturation brightness:self.brightness alpha:self.alpha];
}


#pragma mark - Sorting

- (NSComparisonResult)compareWarmth:(UIColor *)anotherColor
{
    return [@(self.warmth) compare:@(anotherColor.warmth)];
}

- (NSComparisonResult)compareColorfulness:(UIColor *)anotherColor
{
    return [@(self.colorfulness) compare:@(anotherColor.colorfulness)];
}

- (NSComparisonResult)compareHue:(UIColor *)anotherColor
{
    return [@(anotherColor.hue) compare:@(self.hue)];
}

- (NSComparisonResult)compareSaturation:(UIColor *)anotherColor
{
    return [@(anotherColor.saturation) compare:@(self.saturation)];
}

- (NSComparisonResult)compareBrightness:(UIColor *)anotherColor
{
    return [@(self.brightness) compare:@(anotherColor.brightness)];
}


#pragma mark - Distance

- (CGFloat)luminanceDistanceFrom:(UIColor *)anotherColor
{
    CGFloat base = self.luminance - anotherColor.luminance;
    return (CGFloat)sqrt(base * base);
}

- (CGFloat)hueDistanceFrom:(UIColor *)anotherColor
{
    CGFloat dH = self.hue - anotherColor.hue;
    
    return ABS(dH);
}

- (CGFloat)hsDistanceFrom:(UIColor *)anotherColor
{
    CGFloat dH = self.hue - anotherColor.hue;
    CGFloat dS = self.saturation - anotherColor.saturation;
    
    return (CGFloat)sqrt(dH * dH + dS * dS);
}

- (CGFloat)distanceFrom:(UIColor *)anotherColor
{
    CGFloat dR = self.red - anotherColor.red;
    CGFloat dG = self.green - anotherColor.green;
    CGFloat dB = self.blue - anotherColor.blue;
    
    return (CGFloat)sqrt(dR * dR + dG * dG + dB * dB);
}

- (BOOL)isEqualToColor:(UIColor *)anotherColor
{
    CGFloat distance = [self distanceFrom:anotherColor];
    return (distance < FLT_EPSILON);
}


#pragma mark Arithmetic operations

- (instancetype)colorByMultiplyingByRed:(CGFloat)red
                                  green:(CGFloat)green
                                   blue:(CGFloat)blue
                                  alpha:(CGFloat)alpha
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use arithmetic operations");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    return [UIColor colorWithRed:cgfunitclamp(r * red)
                           green:cgfunitclamp(g * green)
                            blue:cgfunitclamp(b * blue)
                           alpha:cgfunitclamp(a * alpha)];
}

- (instancetype)colorByAddingRed:(CGFloat)red
                           green:(CGFloat)green
                            blue:(CGFloat)blue
                           alpha:(CGFloat)alpha
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use arithmetic operations");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    return [UIColor colorWithRed:cgfunitclamp(r + red)
                           green:cgfunitclamp(g + green)
                            blue:cgfunitclamp(b + blue)
                           alpha:cgfunitclamp(a + alpha)];
}

- (instancetype)colorByLighteningToRed:(CGFloat)red
                                 green:(CGFloat)green
                                  blue:(CGFloat)blue
                                 alpha:(CGFloat)alpha
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use arithmetic operations");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    return [UIColor colorWithRed:cgfmax(r, red)
                           green:cgfmax(g, green)
                            blue:cgfmax(b, blue)
                           alpha:cgfmax(a, alpha)];
}

- (instancetype)colorByDarkeningToRed:(CGFloat)red
                                green:(CGFloat)green
                                 blue:(CGFloat)blue
                                alpha:(CGFloat)alpha
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use arithmetic operations");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    return [UIColor colorWithRed:cgfmin(r, red)
                           green:cgfmin(g, green)
                            blue:cgfmin(b, blue)
                           alpha:cgfmin(a, alpha)];
}

- (instancetype)colorByMultiplyingBy:(CGFloat)f
{
    // Multiply by 1 alpha
    return [self colorByMultiplyingByRed:f green:f blue:f alpha:self.alpha];
}

- (instancetype)colorByAdding:(CGFloat)f
{
    // Add 0 alpha
    return [self colorByMultiplyingByRed:f green:f blue:f alpha:self.alpha];
}

- (instancetype)colorByLighteningTo:(CGFloat)f
{
    // Alpha is ignored
    return [self colorByLighteningToRed:f green:f blue:f alpha:self.alpha];
}

- (instancetype)colorByDarkeningTo:(CGFloat)f
{
    // Alpha is ignored
    return [self colorByDarkeningToRed:f green:f blue:f alpha:self.alpha];
}

- (instancetype)colorByMultiplyingByColor:(UIColor *)color
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use arithmetic operations");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    return [self colorByMultiplyingByRed:r green:g blue:b alpha:self.alpha];
}

- (instancetype)colorByAddingColor:(UIColor *)color
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use arithmetic operations");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    return [self colorByAddingRed:r green:g blue:b alpha:self.alpha];
}

- (instancetype)colorByLighteningToColor:(UIColor *)color
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use arithmetic operations");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    return [self colorByLighteningToRed:r green:g blue:b alpha:0.0f];
}

- (instancetype)colorByDarkeningToColor:(UIColor *)color
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use arithmetic operations");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    return [self colorByDarkeningToRed:r green:g blue:b alpha:self.alpha];
}

// Andrew Wooster https://github.com/wooster
- (instancetype)colorByInterpolatingToColor:(UIColor *)color byFraction:(CGFloat)fraction
{
    NSAssert(self.canProvideRGBComponents, @"Self must be a RGB color to use arithmatic operations");
    NSAssert(color.canProvideRGBComponents, @"Color must be a RGB color to use arithmatic operations");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return nil;
    }
    
    CGFloat r2 = 0, g2 = 0, b2 = 0, a2 = 0;
    if (![color getRed:&r2 green:&g2 blue:&b2 alpha:&a2]) {
        return nil;
    }
    
    CGFloat red = r + (fraction * (r2 - r));
    CGFloat green = g + (fraction * (g2 - g));
    CGFloat blue = b + (fraction * (b2 - b));
    CGFloat alpha = a + (fraction * (a2 - a));
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

#pragma mark Complementary Colors, etc
- (instancetype)colorWithBrightness:(CGFloat)brightness
{
    return [UIColor colorWithHue:self.hue saturation:self.saturation brightness:brightness alpha:self.alpha];
}

- (instancetype)colorWithSaturation:(CGFloat)saturation
{
    return [UIColor colorWithHue:self.hue saturation:saturation brightness:self.brightness alpha:self.alpha];
}

- (instancetype)colorWithHue:(CGFloat)hue
{
    return [UIColor colorWithHue:hue saturation:self.saturation brightness:self.brightness alpha:self.alpha];
}

// Pick a color that is likely to contrast well with this color
- (instancetype)contrastingColor
{
    return (self.luminance > 0.5f) ? [UIColor blackColor] : [UIColor whiteColor];
}

// Pick the color that is 180 degrees away in hue
- (instancetype)complementaryColor
{
    // Convert to HSB
    CGFloat h = self.hue * 360.0f;
    CGFloat s = self.saturation;
    CGFloat v = self.brightness;
    CGFloat a = self.alpha;
    
    // Pick color 180 degrees away
    h += 180.0f;
    if (h > 360.f) {
        h -= 360.0f;
    }
    h /= 360.0f;
    
    // Create a color in RGB
    if (a <= 0.0f) {
        a = 1.0f;
    }
    return [UIColor colorWithHue:h saturation:s brightness:v alpha:a];
}

// Pick two colors more colors such that all three are equidistant on the color wheel
// (120 degrees and 240 degress difference in hue from self)
- (NSArray *)triadicColors
{
    return [self analogousColorsWithStepAngle:120.0f pairCount:1];
}

// Pick n pairs of colors, stepping in increasing steps away from this color around the wheel
- (NSArray *)analogousColorsWithStepAngle:(CGFloat)stepAngle pairCount:(NSInteger)pairs
{
    // Convert to HSB
    CGFloat h = self.hue * 360.0f;
    CGFloat s = self.saturation;
    CGFloat v = self.brightness;
    
    NSMutableArray *colors = [NSMutableArray arrayWithCapacity:pairs * 2];
    
    if (stepAngle < 0.0f) {
        stepAngle *= -1.0f;
    }
    
    for (NSInteger i = 1; i <= pairs; ++i) {
        CGFloat a = (CGFloat)fmod(stepAngle * i, 360.0f);
        
        CGFloat h1 = (CGFloat)fmod(h + a, 360.0f);
        CGFloat h2 = (CGFloat)fmod(h + 360.0f - a, 360.0f);
        
        [colors addObject:[UIColor colorWithHue:h1 / 360.0f saturation:s brightness:v alpha:a]];
        [colors addObject:[UIColor colorWithHue:h2 / 360.0f saturation:s brightness:v alpha:a]];
    }
    
    return colors.copy;
}

//  - Eridius - UIColor needs a method that takes 2 colors and gives a third complementary one
- (UIColor *)kevinColorWithColor:(UIColor *)secondColor
{
    CGFloat startingHue = cgfmin(self.hue, secondColor.hue);
    CGFloat distance = ABS(self.hue - secondColor.hue);
    if (distance > 0.5) {
        distance = 1 - distance;
        startingHue = cgfmax(self.hue, secondColor.hue);
    }
    
    CGFloat target = startingHue + distance * 0.5F;
    if (distance < 0.5) {
        target += 0.5;
    }
    
    while (target > 1) {
        target -= 1;
    }
    
    CGFloat sat = (self.saturation + secondColor.saturation) * 0.5f;
    CGFloat bri = (self.brightness + secondColor.brightness) * 0.5f;
    CGFloat alpha = (self.alpha + secondColor.alpha) * 0.5f;
    if (alpha < 0.005f) {
        alpha = 1.0f;
    }
    
    return [UIColor colorWithHue:target saturation:sat brightness:bri alpha:alpha];
}

#pragma mark - Perceived Color
#define  Pr  .299
#define  Pg  .587
#define  Pb  .114

//  public domain function by Darel Rex Finley, 2006
//
//  This function expects the passed-in values to be on a scale
//  of 0 to 1, and uses that same scale for the return values.
//
//  See description/examples at alienryderflex.com/hsp.html

void tcRGBtoHSP(
                CGFloat R, CGFloat G, CGFloat B,
                CGFloat *H, CGFloat *S, CGFloat *P)
{
    if (H == NULL || S == NULL || P == NULL) {
        // It is too much of a pain to check the referencing for each of these bits.
        fprintf(stderr, "Sorry. Please call RGBtoHSP with non-NULL H, S, and P.  Bailing.\n");
        return;
    }
    
    //  Calculate the Perceived brightness.
    *P = (CGFloat)sqrt(R*R*Pr + G*G*Pg + B*B*Pb);
    
    //  Calculate the Hue and Saturation.  (This part works
    //  the same way as in the HSV/B and HSL systems???.)
    if (R==G && R==B) {
        *H=0.;
        *S=0.;
        return;
    }
    
    if (R>=G && R>=B) {   //  R is largest
        if (B>=G) {
            *H=6.f/6.f-1.f/6.f*(B-G)/(R-G);
            *S=1.f-G/R;
        } else {
            *H=0.f/6.f+1.f/6.f*(G-B)/(R-B);
            *S=1.f-B/R;
        }
    } else if (G>=R && G>=B) {   //  G is largest
        if (R>=B) {
            *H=2.f/6.f-1.f/6.f*(R-B)/(G-B);
            *S=1.f-B/G;
        } else {
            *H=2.f/6.f+1.f/6.f*(B-R)/(G-R);
            *S=1.f-R/G;
        }
    } else {   //  B is largest
        if (G>=R) {
            *H=4.f/6.f-1.f/6.f*(G-R)/(B-R);
            *S=1.f-R/B;
        } else {
            *H=4.f/6.f+1.f/6.f*(R-G)/(B-G);
            *S=1.f-G/B;
        }
    }
}



//  public domain function by Darel Rex Finley, 2006
//  see: http://alienryderflex.com/hsp.html
//
//  CGFloated by me. All errors are mine, all good stuff his
//
//  This function expects the passed-in values to be on a scale
//  of 0 to 1, and uses that same scale for the return values.
//
//  Note that some combinations of HSP, even if in the scale
//  0-1, may return RGB values that exceed a value of 1.  For
//  example, if you pass in the HSP color 0,1,1, the result
//  will be the RGB color 2.037,0,0.
//
//  See description/examples at alienryderflex.com/hsp.html

void tcHSPtoRGB(
                CGFloat H, CGFloat S, CGFloat P,
                CGFloat *R, CGFloat *G, CGFloat *B) {
    
    if (R == NULL || G == NULL || B == NULL) {
        // It is too much of a pain to check the referencing for each of these bits.
        fprintf(stderr, "Sorry. Please call with HSPtoRGB with non-NULL R, G, and B.  Bailing.\n");
        return;
    }
    
    CGFloat part = 0.0f, minOverMax = 1.f-S;
    
    if (minOverMax > 0.) {
        if (H < 1.f/6.f) {   //  R>G>B
            H = 6.f*( H-0.f/6.f);
            part = 1.f+H*(1.f/minOverMax-1.f);
            
            *B = P/(CGFloat)sqrt(Pr/minOverMax/minOverMax+Pg*part*part+Pb);
            *R = *B / minOverMax;
            *G = *B + H * (*R - *B);
        } else if (H < 2.f/6.f) {   //  G>R>B
            H = 6.f * (-H + 2.f/6.f);
            part = 1.f + H*(1.f/minOverMax-1.f);
            
            *B = P/(CGFloat)sqrt(Pg/minOverMax/minOverMax+Pr*part*part+Pb);
            *G = *B / minOverMax;
            *R = *B + H*(*G - *B);
        } else if (H < 3.f/6.f) {   //  G>B>R
            H = 6.f*(H - 2.f/6.f);
            part = 1.f + H*(1.f/minOverMax-1.f);
            
            *R = P/(CGFloat)sqrt(Pg/minOverMax/minOverMax+Pb*part*part+Pr);
            *G = *R / minOverMax;
            *B = *R + H*(*G - *R);
        } else if (H < 4.f/6.f) {   //  B>G>R
            H = 6.f*  (-H+4.f/6.f);
            part = 1.f + H*(1.f/minOverMax-1.f);
            
            *R = P/(CGFloat)sqrt(Pb/minOverMax/minOverMax+Pg*part*part+Pr);
            *B = *R / minOverMax;
            *G = *R + H*(*B - *R);
        } else if (H < 5.f/6.f) {   //  B>R>G
            H = 6.f * (H-4.f/6.f);
            part = 1.f + H*(1.f/minOverMax-1.f);
            
            *G = P/(CGFloat)sqrt(Pb/minOverMax/minOverMax+Pr*part*part+Pg);
            *B = *G / minOverMax;
            *R = *G + H*(*B - *G);
        } else {   //  R>B>G
            H = 6.f * (-H+6.f/6.f);
            part = 1.f + H*(1.f/minOverMax-1.f);
            
            *G = P/(CGFloat)sqrt(Pr/minOverMax/minOverMax+Pb*part*part+Pg);
            *R = *G / minOverMax;
            *B = *G + H*(*R - *G);
        }
    } else {
        if (H < 1.f/6.f) {   //  R>G>B
            H = 6.f* (H-0.f/6.f);
            *R = (CGFloat)sqrt(P*P/(Pr+Pg*H*H));
            *G = *R * H;
            *B = 0.f;
        } else if (H < 2.f/6.f) {   //  G>R>B
            H = 6.f * (-H+2.f/6.f);
            *G = (CGFloat)sqrt(P*P/(Pg+Pr*H*H));
            *R = *G * H;
            *B = 0.f;
        } else if (H < 3.f/6.f) {   //  G>B>R
            H = 6.f * (H-2.f/6.f);
            *G = (CGFloat)sqrt(P*P/(Pg+Pb*H*H));
            *B = *G * H;
            *R = 0.f;
        } else if (H < 4.f/6.f) {   //  B>G>R
            H = 6.f* (-H+4.f/6.f);
            *B = (CGFloat)sqrt(P*P/(Pb+Pg*H*H));
            *G = *B * H;
            *R = 0.f;
        } else if (H < 5.f/6.f) {   //  B>R>G
            H = 6.f * (H-4.f/6.f);
            *B = (CGFloat)sqrt(P*P/(Pb+Pr*H*H));
            *R = *B * H;
            *G = 0.f;
        } else {   //  R>B>G
            H = 6.f * (-H+6.f/6.f);
            *R = (CGFloat)sqrt(P*P/(Pr+Pb*H*H));
            *B = *R * H;
            *G = 0.f;
        }
    }
}

// For Ahti333
- (CGFloat)perceivedBrightness
{
    CGFloat h = 0;
    CGFloat s = 0;
    CGFloat p = 0;
    
    CGFloat r = self.red;
    CGFloat g = self.green;
    CGFloat b = self.blue;
    
    tcRGBtoHSP(r, g, b, &h, &s, &p);
    
    return p;
}


#pragma mark - String Support

- (uint32_t)rgbHex
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use -rgbHex");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return 0;
    }
    return (uint32_t)((lrint(r * 0xFF) << 16) | (lrint(g * 0xFF) << 8) | (lrint(b * 0xFF)));
}

- (uint32_t)rgbaHex
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use -rgbaHex");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return 0;
    }
    return (uint32_t)((lrint(r * 0xFF) << 24) | (lrint(g * 0xFF) << 16) | (lrint(b * 0xFF) << 8) | (lrint(a * 0xFF)));
}

- (uint32_t)argbHex
{
    NSAssert(self.canProvideRGBComponents, @"Must be a RGB color to use -argbHex");
    
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![self getRed:&r green:&g blue:&b alpha:&a]) {
        return 0;
    }
    return (uint32_t)((lrint(a * 0xFF) << 24) | (lrint(r * 0xFF) << 16) | (lrint(g * 0xFF) << 8) | (lrint(b * 0xFF)));
}

- (NSString *)stringValue
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -stringValue");
    NSString *result = nil;
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            result = [NSString stringWithFormat:@"{%0.4f, %0.4f, %0.4f, %0.4f}",
                      self.red, self.green, self.blue, self.alpha];
            break;
        case kCGColorSpaceModelMonochrome:
            result = [NSString stringWithFormat:@"{%0.4f, %0.4f}",
                      self.white, self.alpha];
            break;
        default:
            break;
    }
    return result;
}

- (NSString *)rgbaHexStringValue
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -hexStringValue");
    NSString *result = nil;
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            result = [NSString stringWithFormat:@"%02X%02X%02X%02X", self.redByte, self.greenByte, self.blueByte, self.alphaByte];
            break;
        case kCGColorSpaceModelMonochrome:
            result = [NSString stringWithFormat:@"%02X%02X%02X%02X", self.whiteByte, self.whiteByte, self.whiteByte, self.alphaByte];
            break;
        default:
            break;
    }
    return result;
}

- (NSString *)argbHexStringValue
{
    NSAssert(self.canProvideRGBComponents, @"Must be an RGB color to use -hexStringValue");
    NSString *result = nil;
    switch (self.colorSpaceModel) {
        case kCGColorSpaceModelRGB:
            result = [NSString stringWithFormat:@"%02X%02X%02X%02X", self.alphaByte, self.redByte, self.greenByte, self.blueByte];
            break;
        case kCGColorSpaceModelMonochrome:
            result = [NSString stringWithFormat:@"%02X%02X%02X%02X", self.alphaByte, self.whiteByte, self.whiteByte, self.whiteByte];
            break;
        default:
            break;
    }
    return result;
}

- (NSString *)valueString
{
    return [NSString stringWithFormat:@"%@ [%d %d %d]: RGB:(%f, %f, %f) HSB:(%f, %f, %f) CMYK:(%@) alpha: %f",
            self.rgbaHexStringValue,
            self.redByte, self.greenByte, self.blueByte,
            self.red, self.green, self.blue,
            self.hue, self.saturation, self.brightness,
            [self.cmyk componentsJoinedByString:@", "],
            self.alpha];
}

+ (instancetype)colorWithString:(NSString *)stringToConvert
{
    NSScanner *scanner = [NSScanner scannerWithString:stringToConvert];
    if (![scanner scanString:@"{" intoString:NULL]) {
        return nil;
    }
    
    static const NSUInteger kMaxComponents = 4;
    float c[kMaxComponents] = {0};
    NSUInteger i = 0;
    
    if (![scanner scanFloat:&c[i++]]) {
        return nil;
    }
    
    while (true) {
        if ([scanner scanString:@"}" intoString:NULL]) {
            break;
        }
        if (i >= kMaxComponents) {
            return nil;
        }
        if ([scanner scanString:@"," intoString:NULL]) {
            if (![scanner scanFloat:&c[i++]]) {
                return nil;
            }
        } else {
            // either we're at the end of there's an unexpected character here
            // both cases are error conditions
            return nil;
        }
    }
    if (!scanner.isAtEnd) {
        return nil;
    }
    UIColor *color = nil;
    switch (i) {
        case 2: // monochrome
            color = [UIColor colorWithWhite:c[0] alpha:c[1]];
            break;
        case 4: // RGB
            color = [UIColor colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
            break;
        default:
            break;
    }
    return color;
}

+ (instancetype)colorWithRGBHex:(uint32_t)hex
{
    unsigned char r = (hex >> 16) & 0xFF;
    unsigned char g = (hex >> 8) & 0xFF;
    unsigned char b = (hex) & 0xFF;
    
    return [UIColor colorWithRed:r / 255.0f
                           green:g / 255.0f
                            blue:b / 255.0f
                           alpha:1.0f];
}

+ (instancetype)colorWithARGBHex:(uint32_t)hex
{
    unsigned char r = (hex >> 16) & 0xFF;
    unsigned char g = (hex >> 8) & 0xFF;
    unsigned char b = (hex) & 0xFF;
    unsigned char a = (hex >> 24) & 0xFF;
    
    return [UIColor colorWithRed:r / 255.0f
                           green:g / 255.0f
                            blue:b / 255.0f
                           alpha:a / 255.0f];
}

+ (instancetype)colorWithRGBAHex:(uint32_t)hex
{
    unsigned char r = (hex >> 24) & 0xFF;
    unsigned char g = (hex >> 16) & 0xFF;
    unsigned char b = (hex >> 8) & 0xFF;
    unsigned char a = (hex) & 0xFF;
    
    return [UIColor colorWithRed:r / 255.0f
                           green:g / 255.0f
                            blue:b / 255.0f
                           alpha:a / 255.0f];
}

// Return UIColor from Kelvin
// Via http://www.tannerhelland.com/4435/convert-temperature-rgb-algorithm-code/

+ (instancetype)colorWithKelvin:(CGFloat)kelvin
{
    if (kelvin < 1000 || kelvin > 40000) {
        NSLog(@"Warning: temperature should range between 1000 and 40000");
    }
    
    CGFloat temperature = kelvin / 100;
    
    CGFloat red = 0, green = 0, blue = 0;
    
    if (temperature <= 66) {
        red = 0xFF;
        green = temperature;
        green = (CGFloat)(99.4708025861 * log(green) - 161.1195681661);
    } else {
        red = temperature - 60;
        red = (CGFloat)(329.698727446 * pow(red, -0.1332047592));
        green = temperature - 60;
        green = (CGFloat)(288.1221695283 * pow(green, -0.0755148492));
    }
    
    if (temperature >= 66) {
        blue = 0xFF;
    } else if (temperature <= 19) {
        blue = 0;
    } else {
        blue = temperature - 10;
        blue = (CGFloat)(138.5177312231 * log(blue) - 305.0447927307);
    }
    
    
    red = cgfmax(red, 0);
    red = cgfmin(red, 0xFF);
    green = cgfmax(green, 0);
    green = cgfmin(green, 0xFF);
    blue = cgfmax(blue, 0);
    blue = cgfmin(blue, 0xFF);
    
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:1.0f];
}

/*
 Photographers and lighting designers speak of color temperatures in "degrees kelvin." For example, 3200K represents a typical indoor color temperature and 5500K represents typical daylight color temperature. In the context of lighting, a specific kelvin temperature expresses the color temperature (dull red, bright red, white, blue) corresponding to the physical temperature (warm, hot, extremely hot) of an object.
 
 Complete adaptation seems to be confined to the range 5000  K to 5500  K. For most people, D65 has a little hint of blue. Tungsten illumination, at about 3200  K, always appears somewhat yellow.
 */

static NSDictionary *s_kelvin = nil;
+ (NSDictionary *) kelvinDictionary
{
    if (nil != s_kelvin) {
        return s_kelvin;
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    for (NSInteger i = 1000; i <= 40000; i += 100) {
        UIColor *color = [UIColor colorWithKelvin:i];
        NSString *hex = color.rgbaHexStringValue;
        if (nil != hex && nil == dict[hex]) {
            dict[hex] = @(i);
        }
    }
    
    s_kelvin = dict.copy;
    
    return s_kelvin;
}

- (CGFloat)colorTemperature
{
    CGFloat bestDistance = MAXFLOAT;
    NSString *bestMatch = nil;
    
    NSDictionary *kelvinDictionary = [UIColor kelvinDictionary];
    for (NSString *hexKey in kelvinDictionary.allKeys) {
        UIColor *color = [UIColor colorWithRGBHexString:hexKey];
        CGFloat distance = [self distanceFrom:color];
        
        if (distance < bestDistance) {
            bestDistance = distance;
            bestMatch = hexKey;
        }
    }
    
    NSNumber *temp = kelvinDictionary[bestMatch];
    return (CGFloat)temp.doubleValue;
}


+ (BOOL)parseHexString:(NSString *)stringToConvert inHex:(uint32_t *)hex
{
    if (NULL == hex) {
        return NO;
    }
    
    NSString *string = stringToConvert.lowercaseString;
    if ([string hasPrefix:@"#"]) {
        string = [string substringFromIndex:1];
    }
    
    if (![string hasPrefix:@"0x"]) {
        string = [@"0x" stringByAppendingString:string];
    }
    
    NSScanner *scanner = [NSScanner scannerWithString:string];
    
    unsigned int hexNum = 0;
    if (![scanner scanHexInt:&hexNum]) {
        return NO;
    }
    
    *hex = hexNum;
    
    return YES;
}

// Returns a UIColor by scanning the string for a hex number and passing that to +[UIColor colorWithRGBHex:]
// Skips any leading whitespace and ignores any trailing characters
// Added "#" consumer -- via Arnaud Coomans
+ (instancetype)colorWithRGBHexString:(NSString *)stringToConvert
{
    uint32_t hexNum = 0;
    if (![self parseHexString:stringToConvert inHex:&hexNum]) {
        return nil;
    }
    return [UIColor colorWithRGBHex:hexNum];
}

+ (instancetype)colorWithARGBHexString:(NSString *)stringToConvert
{
    uint32_t hexNum = 0;
    if (![self parseHexString:stringToConvert inHex:&hexNum]) {
        return nil;
    }
    return [UIColor colorWithARGBHex:hexNum];
}

+ (instancetype)colorWithRGBAHexString:(NSString *)stringToConvert
{
    uint32_t hexNum = 0;
    if (![self parseHexString:stringToConvert inHex:&hexNum]) {
        return nil;
    }
    return [UIColor colorWithRGBAHex:hexNum];
}


#pragma mark - Random

+ (instancetype)randomColor
{
    static BOOL seeded = NO;
    if (!seeded) {
        seeded = YES;
        srandom((unsigned)time(NULL));
    }
    return [UIColor colorWithRed:random() / (CGFloat) LONG_MAX
                           green:random() / (CGFloat) LONG_MAX
                            blue:random() / (CGFloat) LONG_MAX
                           alpha:1.0f];
}

+ (instancetype)randomDarkColor:(CGFloat)scaleFactor
{
    static BOOL seeded = NO;
    if (!seeded) {
        seeded = YES;
        srandom((unsigned)time(NULL));
    }
    return [UIColor colorWithRed:scaleFactor * random() / (CGFloat) LONG_MAX
                           green:scaleFactor * random() / (CGFloat) LONG_MAX
                            blue:scaleFactor * random() / (CGFloat) LONG_MAX
                           alpha:1.0f];
}

+ (instancetype)randomLightColor:(CGFloat)scaleFactor
{
    static BOOL seeded = NO;
    if (!seeded) {
        seeded = YES;
        srandom((unsigned)time(NULL));
    }
    CGFloat difference = 1.0f - scaleFactor;
    return [UIColor colorWithRed:difference + scaleFactor * random() / (CGFloat) LONG_MAX
                           green:difference + scaleFactor * random() / (CGFloat) LONG_MAX
                            blue:difference + scaleFactor * random() / (CGFloat) LONG_MAX
                           alpha:1.0f];
}

@end


@implementation UIImage (UIColor_Expanded)

- (CGColorSpaceRef)colorSpace
{
    return CGImageGetColorSpace(self.CGImage);
}

- (CGColorSpaceModel)colorSpaceModel
{
    return CGColorSpaceGetModel(self.colorSpace);
}

- (NSString *)colorSpaceString
{
    return [UIColor colorSpaceString:self.colorSpaceModel];
}

@end