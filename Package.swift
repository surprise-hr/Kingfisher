// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Kingfisher",
    platforms: [.iOS(.v10), .macOS(.v10_12), .tvOS(.v10), .watchOS(.v3)],
    products: [
        .library(name: "Kingfisher", targets: ["Kingfisher"])
    ],
	dependencies: [],
    targets: [
        .target(
            name: "Kingfisher",
			dependencies: [	],
            path: "Sources"
        )
    ]
)
