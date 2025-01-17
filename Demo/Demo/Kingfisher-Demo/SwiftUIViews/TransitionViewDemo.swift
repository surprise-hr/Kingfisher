//
<<<<<<<< HEAD:Demo/Demo/Kingfisher-Demo/SwiftUIViews/TransitionViewDemo.swift
//  TransitionViewDemo.swift
//  Kingfisher
//
//  Created by onevcat on 2021/08/03.
//
//  Copyright (c) 2021 Wei Wang <onevcat@gmail.com>
========
//  StubHelpers.swift
//  Kingfisher
//
//  Created by Wei Wang on 2018/10/12.
//
//  Copyright (c) 2019 Wei Wang <onevcat@gmail.com>
>>>>>>>> master:Tests/KingfisherTests/Utils/StubHelpers.swift
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

import SwiftUI
import Kingfisher

<<<<<<<< HEAD:Demo/Demo/Kingfisher-Demo/SwiftUIViews/TransitionViewDemo.swift
@available(iOS 14.0, *)
struct TransitionViewDemo: View {
    @State private var showDetails = false
    
    var body: some View {
        VStack {
            Button(showDetails ? "Hide" : "Show") {
                withAnimation {
                    showDetails.toggle()
                }
            }
            if showDetails {
                KFImage(ImageLoader.sampleImageURLs.first)
                    .transition(.slide)
            }
            Spacer()
        }.frame(height: 500)
    }
}

@available(iOS 14.0, *)
struct TransitionViewDemo_Previews: PreviewProvider {
    static var previews: some View {
        TransitionViewDemo()
    }
========
@discardableResult
func stub(_ url: URL, data: Data, statusCode: Int = 200, length: Int? = nil) -> LSStubResponseDSL {
    var stubResult = stubRequest("GET", url.absoluteString as NSString).andReturn(statusCode)?.withBody(data as NSData)
    if let length = length {
        stubResult = stubResult?.withHeader("Content-Length", "\(length)")
    }
    return stubResult!
}

func delayedStub(_ url: URL, data: Data, statusCode: Int = 200, length: Int? = nil) -> LSStubResponseDSL {
    let result = stub(url, data: data, statusCode: statusCode, length: length)
    return result.delay()!
}

func stub(_ url: URL, errorCode: Int) {
    let error = NSError(domain: "stubError", code: errorCode, userInfo: nil)
    stub(url, error: error)
}

func stub(_ url: URL, error: Error) {
    return stubRequest("GET", url.absoluteString as NSString).andFailWithError(error)
>>>>>>>> master:Tests/KingfisherTests/Utils/StubHelpers.swift
}
