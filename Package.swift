// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Kingfisher",
    platforms: [.iOS(.v13), .macOS(.v10_12), .tvOS(.v10), .watchOS(.v3)],
    products: [
        .library(name: "Kingfisher", targets: ["Kingfisher"])
    ],
	dependencies: [
		.package(url: "https://github.com/SDWebImage/librlottie-Xcode", from: "0.2.1"),
	],
    targets: [
        .target(
            name: "Kingfisher",
			dependencies: [
				.product(name: "librlottie", package: "librlottie-Xcode"),
			],
            path: "Sources"
        )
    ]
)
