// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "niimbot_label_printer",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(name: "niimbot_label_printer", targets: ["niimbot_label_printer"])
    ],
    dependencies: [

    ],
    targets: [
        .target(
            name: "niimbot_label_printer",
            dependencies: [],
            resources: [],
            publicHeadersPath: "",
            cSettings: [
                .headerSearchPath("include")
            ]
        )
    ]
)
