//
//  LottieImage.swift
//  Kingfisher
//
//  Created by sergiikostanian on 13.04.2021.
//
//  Copyright (c) 2021 Wei Wang <onevcat@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

struct LottieImage: Codable {

    struct Frame: Codable {
        let data: Data
        let width: Int
        let height: Int
        let bytesPerRow: Int

        init?(cgImage: CGImage) {
            guard let data = cgImage.dataProvider?.data else { return nil }
            self.data = data as Data
            self.width = cgImage.width
            self.height = cgImage.height
            self.bytesPerRow = cgImage.bytesPerRow
        }
    }

    static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    static let bitsPerComponent: Int = 8
    static let bitsPerPixel: Int = 32

    let frames: [Frame]
    let duration: Double

    init(cgImages: [CGImage], duration: Double) {
        self.frames = cgImages.compactMap({ Frame(cgImage: $0) })
        self.duration = duration
    }

    init(frames: [Frame], duration: Double) {
        self.frames = frames
        self.duration = duration
    }
}

extension LottieImage {

    func makeAnimatedFrames() -> [LottieImageView.AnimatedFrame] {
        let frameDuration = duration / Double(frames.count)
        var animatedFrames: [LottieImageView.AnimatedFrame] = []

        for index in 0..<frames.count {
            guard let image = makeImageForFrame(at: index) else { continue }
            animatedFrames.append(LottieImageView.AnimatedFrame(image: image, duration: frameDuration))
        }
        return animatedFrames
    }

    func makeImageForFrame(at index: Int) -> UIImage? {
        guard index < frames.count else { return nil }
        let frame = frames[index]

        guard let dataProvider = CGDataProvider(data: frame.data as CFData) else { return nil }
        guard let cgImage = CGImage(width: frame.width,
                                    height: frame.height,
                                    bitsPerComponent: LottieImage.bitsPerComponent,
                                    bitsPerPixel: LottieImage.bitsPerPixel,
                                    bytesPerRow: frame.bytesPerRow,
                                    space: LottieImage.colorSpace,
                                    bitmapInfo: LottieImage.bitmapInfo,
                                    provider: dataProvider,
                                    decode: nil,
                                    shouldInterpolate: true,
                                    intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
