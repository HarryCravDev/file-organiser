// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DigitalDeclutter",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DigitalDeclutterCore", targets: ["DigitalDeclutterCore"]),
        .executable(name: "DigitalDeclutterCLI", targets: ["DigitalDeclutterCLI"]),
        .executable(name: "DigitalDeclutterUI", targets: ["DigitalDeclutterUI"])
    ],
    targets: [
        .target(
            name: "DigitalDeclutterCore",
            path: "Sources/DigitalDeclutterCore"
        ),
        .executableTarget(
            name: "DigitalDeclutterCLI",
            dependencies: ["DigitalDeclutterCore"],
            path: "Sources/DigitalDeclutterCLI"
        ),
        .executableTarget(
            name: "DigitalDeclutterUI",
            dependencies: ["DigitalDeclutterCore"],
            path: "Sources/DigitalDeclutterUI"
        )
    ]
)
