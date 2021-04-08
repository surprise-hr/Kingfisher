//
//  AnimatableImageView.swift
//  Kingfisher
//
//  Created by bl4ckra1sond3tre on 4/22/16.
//
//  The AnimatableImageView, AnimatedFrame and Animator is a modified version of
//  some classes from kaishin's Gifu project (https://github.com/kaishin/Gifu)
//
//  The MIT License (MIT)
//
//  Copyright (c) 2019 Reda Lemeden.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  The name and characters used in the demo of this software are property of their
//  respective owners.

#if !os(watchOS)
#if canImport(UIKit)
import UIKit
import ImageIO
import librlottie

/// Protocol of `LottieImageView`.
public protocol LottieImageViewDelegate: AnyObject {

    /// Called after the animatedImageView has finished each animation loop.
    ///
    /// - Parameters:
    ///   - imageView: The `LottieImageView` that is being animated.
    ///   - count: The looped count.
    func animatedImageView(_ imageView: LottieImageView, didPlayAnimationLoops count: UInt)

    /// Called after the `LottieImageView` has reached the max repeat count.
    ///
    /// - Parameter imageView: The `LottieImageView` that is being animated.
    func animatedImageViewDidFinishAnimating(_ imageView: LottieImageView)
}

extension LottieImageViewDelegate {
    public func animatedImageView(_ imageView: LottieImageView, didPlayAnimationLoops count: UInt) {}
    public func animatedImageViewDidFinishAnimating(_ imageView: LottieImageView) {}
}

/// Represents a subclass of `UIImageView` for displaying animated image.
/// Different from showing animated image in a normal `UIImageView` (which load all frames at one time),
/// `LottieImageView` only tries to load several frames (defined by `framePreloadCount`) to reduce memory usage.
/// It provides a tradeoff between memory usage and CPU time. If you have a memory issue when using a normal image
/// view to load GIF data, you could give this class a try.
///
/// Kingfisher supports setting GIF animated data to either `UIImageView` and `LottieImageView` out of box. So
/// it would be fairly easy to switch between them.
open class LottieImageView: UIImageView {

    /// Proxy object for preventing a reference cycle between the `CADDisplayLink` and `LottieImageView`.
    class TargetProxy {
        private weak var target: LottieImageView?

        init(target: LottieImageView) {
            self.target = target
        }

        @objc func onScreenUpdate() {
            target?.updateFrameIfNeeded()
        }
    }

    /// Enumeration that specifies repeat count of GIF
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

    /// The count of the frames should be preloaded before shown.
    public var framePreloadCount = 10

    /// Specifies whether the GIF frames should be pre-scaled to the image view's size or not.
    /// If the downloaded image is larger than the image view's size, it will help to reduce some memory use.
    /// Default is `true`.
    public var needsPrescaling = true

    /// Decode the GIF frames in background thread before using. It will decode frames data and do a off-screen
    /// rendering to extract pixel information in background. This can reduce the main thread CPU usage.
    public var backgroundDecode = true

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

    public var lottieImageData: Data? {
        didSet {
            if lottieImageData != oldValue {
                reset()
            }
            setNeedsDisplay()
            layer.setNeedsDisplay()
        }
    }

    /// Delegate of this `LottieImageView` object. See `LottieImageViewDelegate` protocol for more.
    public weak var delegate: LottieImageViewDelegate?

    /// The `Animator` instance that holds the frames of a specific image in memory.
    public private(set) var animator: Animator?

    // MARK: - Private property
    // Dispatch queue used for preloading images.
    private lazy var preloadQueue: DispatchQueue = {
        return DispatchQueue(label: "com.onevcat.Kingfisher.LottieAnimator.preloadQueue")
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
            let targetSize = bounds.scaled(UIScreen.main.scale).size
            let animator = Animator(
                imageData: imageData,
                contentMode: contentMode,
                size: targetSize,
                framePreloadCount: framePreloadCount,
                repeatCount: repeatCount,
                preloadQueue: preloadQueue)
            animator.delegate = self
            animator.needsPrescaling = needsPrescaling
            animator.backgroundDecode = backgroundDecode
            animator.prepareFramesAsynchronously()
            self.animator = animator
        }
        didMove()
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

protocol LottieAnimatorDelegate: AnyObject {
    func animator(_ animator: LottieImageView.Animator, didPlayAnimationLoops count: UInt)
}

extension LottieImageView: LottieAnimatorDelegate {
    func animator(_ animator: Animator, didPlayAnimationLoops count: UInt) {
        delegate?.animatedImageView(self, didPlayAnimationLoops: count)
    }
}
#endif
#endif
