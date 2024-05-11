// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Bucketeer",
    platforms: [.iOS(.v11)],
    products: [
        .library(
            name: "Bucketeer",
            targets: ["Bucketeer"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Bucketeer",
            path: "./Bucketeer",
            resources: [.copy("PrivacyInfo.xcprivacy")]),
        .testTarget(
            name: "BucketeerTests",
            dependencies: ["Bucketeer"],
            path: "./BucketeerTests"
        )
    ]
)
