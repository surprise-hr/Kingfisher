// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Kingfisher",
    platforms: [.iOS(.v10), .macOS(.v10_12), .tvOS(.v10), .watchOS(.v3)],
    products: [
        .library(name: "Kingfisher", targets: ["Kingfisher"])
    ],
	dependencies: [
		.package(url: "https://github.com/airbnb/lottie-ios.git", from: "3.3.0")
	],
    targets: [
        .target(
            name: "Kingfisher",
			dependencies: ["Lottie"],
            path: "Sources"
        )
    ]
)
