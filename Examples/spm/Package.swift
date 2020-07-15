// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "spm",
    dependencies: [
        // libSwiftPM
        .package(path: "../../"),

        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.8.0"),
        .package(url: "https://github.com/grpc/grpc-swift.git", .revision("efb67a324eaf1696b50e66bc471a53690e41fbf6")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.2.0"),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", .branch("master")),
    ],
    targets: [
        // Top-level tool for SwiftPM service and client.
        .target(
            name: "spm",
            dependencies: [
                "ArgumentParser",
                "SwiftToolsSupport-auto",
                "SPMServiceClient",
                "SPMService",
            ]
        ),

        // SwiftPM service client.
        .target(
            name: "SPMServiceClient",
            dependencies: [
                "SwiftToolsSupport-auto",
                "SPMServiceProtocol",
                "GRPC",
            ]
        ),

        .target(
            name: "SPMService",
            dependencies: [
                "SwiftToolsSupport-auto",
                "SPMServiceProtocol",
                "GRPC",
                "SwiftPM-auto",
            ]
        ),

        .target(
            name: "SPMServiceProtocol",
            dependencies: [
                "SwiftProtobuf",
                "GRPC",
            ],
            path: "./SPMServiceProtocol"
        ),
    ]
)
