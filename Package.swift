// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TorrentLibrary",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v4),
        .macOS(.v10_13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TorrentLibrary",
            targets: ["TorrentLibrary"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nothingsh/TorrentModel", .upToNextMajor(from: "1.0.3")),
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", .upToNextMajor(from: "7.0.0")),
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs", .upToNextMajor(from: "9.0.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TorrentLibrary",
            dependencies: ["TorrentModel", "Alamofire", "CocoaAsyncSocket"],
            path: "Sources"),
        .testTarget(
            name: "TorrentLibraryTests",
            dependencies: [
                .target(name: "TorrentLibrary"),
                .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs")
            ]),
    ]
)
