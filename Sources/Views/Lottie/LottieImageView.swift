//
//  LottieImageView.swift
//  Kingfisher
//
//  Created by sergiikostanian on 08.04.2021.
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

/// Represents a subclass of `UIImageView` for decoding bodymovin JSON animation using
/// rLottie engine and playing it frame by frame.
open class LottieImageView: UIImageView {

    /// Proxy object for preventing a reference cycle between the `CADisplayLink` and `LottieImageView`.
    class TargetProxy {
        private weak var target: LottieImageView?

        init(target: LottieImageView) {
            self.target = target
        }

        @objc func onScreenUpdate() {
            target?.updateFrameIfNeeded()
        }
    }

    /// Enumeration that specifies animation repeat count.
    public enum RepeatCount: Equatable {
        case once
        case finite(count: UInt)
        case infinite

        public static func ==(lhs: RepeatCount, rhs: RepeatCount) -> Bool {
            switch (lhs, rhs) {
            case let (.finite(l), .finite(r)):
                return l == r
            case (.once, .once),
                 (.infinite, .infinite):
                return true
            case (.once, .finite(let count)),
                 (.finite(let count), .once):
                return count == 1
            case (.once, _),
                 (.infinite, _),
                 (.finite, _):
                return false
            }
        }
    }

    // MARK: - Public property
    /// Whether automatically play the animation when the view become visible. Default is `true`.
    public var autoPlayAnimatedImage = true
    /// Whether set first frame as a placeholder as soon as we got it decoded. Default is `true`.
    public var useFirstFrameAsPlaceholder = true

    /// The animation timer's run loop mode. Default is `RunLoop.Mode.common`.
    /// Set this property to `RunLoop.Mode.default` will make the animation pause during UIScrollView scrolling.
    public var runLoopMode = KFRunLoopModeCommon {
        willSet {
            guard runLoopMode != newValue else { return }
            stopAnimating()
            displayLink.remove(from: .main, forMode: runLoopMode)
            displayLink.add(to: .main, forMode: newValue)
            startAnimating()
        }
    }

    /// The repeat count. The animated image will keep animate until it the loop count reaches this value.
    /// Setting this value to another one will reset current animation.
    ///
    /// Default is `.infinite`, which means the animation will last forever.
    public var repeatCount = RepeatCount.infinite {
        didSet {
            if oldValue != repeatCount {
                reset()
                setNeedsDisplay()
                layer.setNeedsDisplay()
            }
        }
    }

    /// Delegate of this `LottieImageView` object. See `LottieImageViewDelegate` protocol for more.
    public weak var delegate: LottieImageViewDelegate?

    /// The `Animator` instance that holds the frames of a specific image in memory.
    public private(set) var animator: Animator?

    // MARK: - Private property
    // Dispatch queue used for rendering images from the Lottie data.
    private lazy var renderingQueue: DispatchQueue = {
        return DispatchQueue(label: "com.onevcat.Kingfisher.Animator.renderingQueue")
    }()

    // A flag to avoid invalidating the displayLink on deinit if it was never created, because displayLink is so lazy.
    private var isDisplayLinkInitialized: Bool = false

    // A display link that keeps calling the `updateFrame` method on every screen refresh.
    private lazy var displayLink: CADisplayLink = {
        isDisplayLinkInitialized = true
        let displayLink = CADisplayLink(
            target: TargetProxy(target: self), selector: #selector(TargetProxy.onScreenUpdate))
        displayLink.add(to: .main, forMode: runLoopMode)
        displayLink.isPaused = true
        return displayLink
    }()

    // Preferred resulting animation frame size.
    private var frameSize: CGSize?

    // The data of the lottie animation.
    private var lottieImageData: Data? {
        didSet {
            if lottieImageData != oldValue {
                reset()
            }
            setNeedsDisplay()
            layer.setNeedsDisplay()
        }
    }

    // MARK: - Public methods

    /// Sets the data of the lottie animation. Decoding and preparing animation frames will start immidiately.
    ///
    /// - Parameters:
    ///   - imageData: A lottie JSON animated image data.
    ///   - frameSize: The resulting animation frames size. If `nil` is specified default size will be used.
    public func setImageData(_ imageData: Data?, frameSize: CGSize? = nil) {
        self.frameSize = frameSize
        self.lottieImageData = imageData
    }

    /// Sets the current playback to the specified position.
    ///
    /// - Parameter position: The normalized position which has to be set. Takes values in range `0...1`.
    public func seek(to position: Float) {
        guard (0.0...1.0).contains(position) else { return }
        guard let animator = animator, animator.isPreparedFrames else { return }
        let index = Int(Float(animator.frameCount) * position)
        guard let currentFrame = animator.frame(at: index) else { return }
        animator.currentFrameIndex = index
        layer.contents = currentFrame.cgImage
    }

    // MARK: - Override

    deinit {
        if isDisplayLinkInitialized {
            displayLink.invalidate()
        }
    }

    override open var isAnimating: Bool {
        if isDisplayLinkInitialized {
            return !displayLink.isPaused
        } else {
            return super.isAnimating
        }
    }

    /// Starts the animation.
    override open func startAnimating() {
        guard !isAnimating else { return }
        guard let animator = animator else { return }
        guard !animator.isReachMaxRepeatCount else { return }

        displayLink.isPaused = false
    }

    /// Stops the animation.
    override open func stopAnimating() {
        super.stopAnimating()
        if isDisplayLinkInitialized {
            displayLink.isPaused = true
        }
    }

    override open func display(_ layer: CALayer) {
        if let currentFrame = animator?.currentFrameImage {
            layer.contents = currentFrame.cgImage
        } else {
            layer.contents = image?.cgImage
        }
    }

    override open func didMoveToWindow() {
        super.didMoveToWindow()
        didMove()
    }

    override open func didMoveToSuperview() {
        super.didMoveToSuperview()
        didMove()
    }

    // This is for back compatibility that using regular `UIImageView` to show animated image.
    override func shouldPreloadAllAnimation() -> Bool {
        return false
    }

    // Reset the animator.
    private func reset() {
        animator = nil
        if let imageData = lottieImageData {
            setupAnimator(with: imageData)
        }
        didMove()
    }

    private func setupAnimator(with imageData: Data) {
        let animator = Animator(repeatCount: repeatCount,
                                renderingQueue: renderingQueue)
        animator.delegate = self
        animator.prepareFramesAsynchronously(with: imageData, frameSize: frameSize)
        self.animator = animator
    }

    private func didMove() {
        if autoPlayAnimatedImage && animator != nil {
            if let _ = superview, let _ = window {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }

    /// Update the current frame with the displayLink duration.
    private func updateFrameIfNeeded() {
        guard let animator = animator else {
            return
        }

        guard !animator.isFinished else {
            stopAnimating()
            delegate?.animatedImageViewDidFinishAnimating(self)
            return
        }

        let duration: CFTimeInterval

        // CA based display link is opt-out from ProMotion by default.
        // So the duration and its FPS might not match.
        // See [#718](https://github.com/onevcat/Kingfisher/issues/718)
        // By setting CADisableMinimumFrameDuration to YES in Info.plist may
        // cause the preferredFramesPerSecond being 0
        let preferredFramesPerSecond = displayLink.preferredFramesPerSecond
        if preferredFramesPerSecond == 0 {
            duration = displayLink.duration
        } else {
            // Some devices (like iPad Pro 10.5) will have a different FPS.
            duration = 1.0 / TimeInterval(preferredFramesPerSecond)
        }

        animator.shouldChangeFrame(with: duration) { [weak self] hasNewFrame in
            if hasNewFrame {
                self?.layer.setNeedsDisplay()
            }
        }
    }
}

extension LottieImageView: LottieAnimatorDelegate {

    func animator(_ animator: Animator, didPlayAnimationLoops count: UInt) {
        delegate?.animatedImageView(self, didPlayAnimationLoops: count)
    }

    func animator(_ animator: LottieImageView.Animator, didDecodeFirstFrame image: UIImage) {
        guard useFirstFrameAsPlaceholder else { return }
        self.image = image
    }

    func animatorDidFinishDecoding(_ animator: Animator) {
        delegate?.animatedImageViewDidPreparedAnimation(self)
    }
}

#endif
#endif
