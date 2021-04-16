//
//  LottieImageView+Animator.swift
//  Kingfisher
//
//  Created by sergiikostanian on 07.04.2021.
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

#if !os(watchOS)
#if canImport(UIKit)
import UIKit
import ImageIO
import librlottie
import CoreGraphics

/// The delegate of `LottieImageView.Animator` events.
protocol LottieAnimatorDelegate: AnyObject {
    func animator(_ animator: LottieImageView.Animator, didPlayAnimationLoops count: UInt)
    func animator(_ animator: LottieImageView.Animator, didDecodeFirstFrame image: UIImage)
    func animatorDidFinishDecoding(_ animator: LottieImageView.Animator)
}

extension LottieImageView {

    // MARK: - Animator

    /// An animator which used to drive the data behind `LottieImageView`.
    public class Animator {

        /// The image of the current frame.
        public var currentFrameImage: UIImage? {
            return frame(at: currentFrameIndex)
        }

        /// The image of the first frame.
        public var firstFrameImage: UIImage? {
            return frame(at: 0)
        }

        /// The duration of the current active frame duration.
        public var currentFrameDuration: TimeInterval {
            return duration(at: currentFrameIndex)
        }

        /// The index of the current animation frame.
        public internal(set) var currentFrameIndex = 0

        public private(set) var isPreparedFrames = false

        /// Whether the current frame is the last frame or not in the animation sequence.
        public var isLastFrame: Bool {
            return currentFrameIndex == frameCount - 1
        }

        var isReachMaxRepeatCount: Bool {
            switch maxRepeatCount {
            case .once:
                return currentRepeatCount >= 1
            case .finite(let maxCount):
                return currentRepeatCount >= maxCount
            case .infinite:
                return false
            }
        }

        weak var delegate: LottieAnimatorDelegate?

        // Total duration of one animation loop
        var loopDuration: TimeInterval = 0
        var isFinished: Bool = false

        private(set) var frameCount = 0

        /// The animation object that can build the contents of the Lottie resource.
        private let maxRepeatCount: RepeatCount
        private let maxTimeStep: TimeInterval = 1.0
        private let animatedFrames = SafeArray<AnimatedFrame>()
        private var frameSize: CGSize?
        private var timeSinceLastFrameChange: TimeInterval = 0.0
        private var currentRepeatCount: UInt = 0

        private lazy var renderingQueue: DispatchQueue = {
            return DispatchQueue(label: "com.onevcat.Kingfisher.Animator.renderingQueue")
        }()

        /// Creates an animator with image source reference.
        ///
        /// - Parameters:
        ///   - repeatCount: The repeat count should this animator uses.
        ///   - renderingQueue: A queue that will be used for rendering operations.
        init(repeatCount: RepeatCount,
             renderingQueue: DispatchQueue) {
            self.maxRepeatCount = repeatCount
            self.renderingQueue = renderingQueue
        }

        /// Gets the image frame of a given index.
        /// - Parameter index: The index of desired image.
        /// - Returns: The decoded image at the frame. `nil` if the index is out of bound or the image is not yet loaded.
        public func frame(at index: Int) -> UIImage? {
            return animatedFrames[index]?.image
        }

        public func duration(at index: Int) -> TimeInterval {
            return animatedFrames[index]?.duration ?? .infinity
        }

        func prepareFramesAsynchronously(with imageData: Data, frameSize: CGSize?) {
            renderingQueue.async {
                self.frameSize = frameSize
                let imageSource = self.prepareImageSource(from: imageData)
                self.frameCount = lottie_animation_get_totalframe(imageSource)
                self.loopDuration = lottie_animation_get_duration(imageSource)
                self.animatedFrames.reserveCapacity(self.frameCount)
                self.setupAnimatedFrames(with: imageSource)
            }
        }

        func shouldChangeFrame(with duration: CFTimeInterval, handler: (Bool) -> Void) {
            incrementTimeSinceLastFrameChange(with: duration)

            if currentFrameDuration > timeSinceLastFrameChange {
                handler(false)
            } else {
                resetTimeSinceLastFrameChange()
                incrementCurrentFrameIndex()
                handler(true)
            }
        }

        private func prepareImageSource(from imageData: Data) -> OpaquePointer {
            let resourcePath = Bundle.main.resourcePath
            let jsonString = String(data: imageData, encoding: .utf8)
            let jsonDataBuffer = jsonString?.cString(using: .utf8)
            let resourcePathBuffer = resourcePath?.cString(using: .utf8)
            return lottie_animation_from_data(jsonDataBuffer, "", resourcePathBuffer)
        }

        private func setupAnimatedFrames(with imageSource: OpaquePointer) {
            resetAnimatedFrames()

            let frameDuration: TimeInterval = 1 / lottie_animation_get_framerate(imageSource)

            // Lottie surface use ARGB8888 Premultiplied
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

            var width: size_t = 0
            var height: size_t = 0
            if let frameSize = frameSize {
                width = Int(ceil(frameSize.width))
                height = Int(ceil(frameSize.height))
            } else {
                lottie_animation_get_size(imageSource, &width, &height)
            }

            guard let canvas = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
                return
            }

            for index in 0..<frameCount {
                guard let frame = loadFrame(at: index, imageSource: imageSource, canvas: canvas, height: height, width: width) else { continue }
                animatedFrames.append(AnimatedFrame(image: frame, duration: frameDuration))

                if index == 0 {
                    DispatchQueue.main.async {
                        self.delegate?.animator(self, didDecodeFirstFrame: frame)
                    }
                }
            }

            // Remove image source from memory when finished decoding.
            lottie_animation_destroy(imageSource)

            DispatchQueue.main.async {
                self.isPreparedFrames = true
                self.delegate?.animatorDidFinishDecoding(self)
            }
        }

        private func resetAnimatedFrames() {
            animatedFrames.removeAll()
        }

        private func loadFrame(at index: Int, imageSource: OpaquePointer, canvas: CGContext, height: Int, width: Int) -> UIImage? {
            let buffer = UnsafeMutablePointer<UInt32>(OpaquePointer(canvas.data))
            lottie_animation_render(imageSource, index, buffer, width, height, canvas.bytesPerRow)

            guard let cgImage = canvas.makeImage() else {
                return nil
            }

            return UIImage(cgImage: cgImage)
        }

        private func incrementCurrentFrameIndex() {
            currentFrameIndex = increment(frameIndex: currentFrameIndex)
            if isLastFrame {
                currentRepeatCount += 1
                if isReachMaxRepeatCount {
                    isFinished = true
                }
                delegate?.animator(self, didPlayAnimationLoops: currentRepeatCount)
            }
        }

        private func incrementTimeSinceLastFrameChange(with duration: TimeInterval) {
            timeSinceLastFrameChange += min(maxTimeStep, duration)
        }

        private func resetTimeSinceLastFrameChange() {
            timeSinceLastFrameChange -= currentFrameDuration
        }

        private func increment(frameIndex: Int, by value: Int = 1) -> Int {
            return (frameIndex + value) % frameCount
        }
    }
}
#endif
#endif
