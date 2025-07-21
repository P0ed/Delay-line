#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

static UIImage *UIImageGrayscaleImageWithData(const char *data, int width, int height) {
	CGColorSpaceRef color = CGColorSpaceCreateDeviceGray();
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, width * height, NULL);

	CGImageRef img = CGImageCreate(width, height, 8, 8, width, color, kCGBitmapByteOrderDefault | kCGImageAlphaNone, provider, NULL, false, kCGRenderingIntentDefault);

	CGDataProviderRelease(provider);
	CGColorSpaceRelease(color);

	UIImage *image = [UIImage imageWithCGImage:img];
	CGImageRelease(img);

	return image;
}

