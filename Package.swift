// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "unigame",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "unigame",
            targets: ["unigame"]),
    ],
    dependencies: [
        .package(url: "https://github.com/joshuaauerbachwatson/AuerbachLook.git", branch: "main"),
        .package(url: "https://github.com/auth0/Auth0.swift", .upToNextMajor(from: "2.10.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "unigame",
            dependencies: [
                .product(name: "AuerbachLook", package: "auerbachlook"),
                .product(name: "Auth0", package: "Auth0.swift")
            ],
            resources: [.process("Resources")]),
        .testTarget(name: "unigame-tests",
            dependencies: [
                .product(name: "AuerbachLook", package: "auerbachlook"),
                .product(name: "Auth0", package: "Auth0.swift")
            ])
    ]
)
