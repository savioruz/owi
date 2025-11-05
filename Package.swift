// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "owi",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(
            name: "Owi",
            targets: ["Owi"]
        ),
        .executable(
            name: "owi",
            targets: ["OwiCLI"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.3.0"
        ),
        .package(
            url: "https://github.com/vapor/postgres-kit.git",
            from: "2.0.0"
        ),
        .package(url: "https://github.com/vapor/mysql-kit.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/sqlite-kit.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "Owi",
            dependencies: [
                .product(name: "PostgresKit", package: "postgres-kit"),
                .product(name: "MySQLKit", package: "mysql-kit"),
                .product(name: "SQLiteKit", package: "sqlite-kit"),
            ]
        ),
        .executableTarget(
            name: "OwiCLI",
            dependencies: [
                "Owi",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
            ]
        ),
        .testTarget(
            name: "OwiTests",
            dependencies: ["Owi"]
        ),
    ]
)
