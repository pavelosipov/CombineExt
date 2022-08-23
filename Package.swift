// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "CombineExt",
    platforms: [
      .iOS(.v12), .macOS(.v10_14), .tvOS(.v12), .watchOS(.v5),
    ],
    products: [
        .library(name: "CombineExt", targets: ["CombineExt"]),
    ],
    dependencies: [
        .package(url: "https://github.com/OpenCombine/OpenCombine", from: "0.13.0"),
        .package(url: "https://github.com/pavelosipov/combine-schedulers", from: "0.7.2"),
    ],
    targets: [
        .target(name: "CombineExt",
                dependencies: [
                    .product(name: "OpenCombine", package: "OpenCombine"),
                    .product(name: "OpenCombineFoundation", package: "OpenCombine"),
                    .product(name: "OpenCombineDispatch", package: "OpenCombine"),
                ],
                path: "Sources"),
        .testTarget(name: "CombineExtTests",
                    dependencies: [
                        "CombineExt",
                        .product(name: "CombineSchedulers", package: "combine-schedulers")
                    ],
                    path: "Tests"),
    ],
    swiftLanguageVersions: [.v5]
)
