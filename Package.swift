// swift-tools-version:6.0
//
// Memoirs
//
// Created by Alex Babaev on 10 May 2021.
// Copyright © 2021 Alex Babaev. All rights reserved.
// License: MIT License, https://github.com/redmadrobot-spb/memoirs-ios/blob/main/LICENSE
//

import PackageDescription

let swiftSettings: [SwiftSetting] = [
]

let package = Package(
    name: "Memoirs",
    platforms: [ .iOS(.v17), .tvOS(.v17), .watchOS(.v11), .macOS(.v15), .macCatalyst(.v17) ],
    products: [
        .library(name: "Memoirs", targets: [ "Memoirs" ]),
        .executable(name: "ExampleMemoirs", targets: [ "ExampleMemoirs" ]),
    ],
    dependencies: [
//        .package(name: "MemoirMacros", path: "Macros"),
    ],
    targets: [
        .target(name: "MemoirsWorkaroundC", dependencies: [], path: "Sources.Workaround"),
        .target(
            name: "Memoirs",
            dependencies: [
                "MemoirsWorkaroundC",
//                .product(name: "MemoirMacros", package: "MemoirMacros")
            ],
            path: "Sources",
            swiftSettings: swiftSettings
        ),

        .testTarget(name: "MemoirsTests", dependencies: [ "Memoirs" ]),
        .executableTarget(name: "ExampleMemoirs", dependencies: [ "Memoirs" ], path: "Sources.Example"),
    ],
    swiftLanguageModes: [.v6]
)
