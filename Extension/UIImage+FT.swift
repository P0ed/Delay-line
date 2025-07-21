import UIKit

extension UIImage {

	convenience init(ft: UIFT) {
		let w = Int(UIFTWidth)
		let h = Int(UIFTHeight)
		let space = CGColorSpaceCreateDeviceGray()
		let provider = CGDataProvider(
			dataInfo: nil,
			data: ft.data,
			size: w * h,
			releaseData: { _, _, _ in }
		)
		guard let provider else { self.init(); return }

		let img = CGImage(
			width: w,
			height: h,
			bitsPerComponent: 8,
			bitsPerPixel: 8,
			bytesPerRow: w,
			space: space,
			bitmapInfo: .byteOrderDefault,
			provider: provider,
			decode: nil,
			shouldInterpolate: false,
			intent: .defaultIntent
		)
		guard let img else { self.init(); return }

		self.init(cgImage: img)
	}
}
