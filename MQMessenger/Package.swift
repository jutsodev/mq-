// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MQMessenger",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "MQMessenger", targets: ["MQMessenger"]),
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.1.0"),
        .package(url: "https://github.com/onevcat/Kingfisher", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "MQMessenger",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift"),
                .product(name: "Kingfisher", package: "Kingfisher"),
            ],
            path: "MQMessenger"
        ),
    ]
)
