// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "niimbot",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(name: "niimbot", targets: ["niimbot"])
    ],
    dependencies: [

    ],
    targets: [
        .target(
            name: "niimbot",
            dependencies: [],
            resources: [],
            publicHeadersPath: "",
            cSettings: [
                .headerSearchPath("include")
            ]
        )
    ]
)
