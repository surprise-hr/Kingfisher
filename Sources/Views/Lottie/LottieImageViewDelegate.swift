//
//  LottieImageViewDelegate.swift
//  Kingfisher
//
//  Created by sergiikostanian on 14.04.2021.
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

/// The delegate of `LottieImageView` events.
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

#endif
#endif
