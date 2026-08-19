// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CountdownCore",
    platforms: [.iOS(.v17)],
    products: [
        // 纯 Foundation：领域模型、日期计算、文案。App 与 Widget 共用，可在任意平台跑测试。
        .library(name: "CountdownKit", targets: ["CountdownKit"]),
        // 设计代币层。视图层唯一允许引用的样式来源。
        .library(name: "DesignTokens", targets: ["DesignTokens"]),
        // SwiftData 持久化 + 仓储。
        .library(name: "CountdownStore", targets: ["CountdownStore"]),
    ],
    targets: [
        .target(name: "CountdownKit"),
        .target(name: "DesignTokens", dependencies: ["CountdownKit"]),
        .target(name: "CountdownStore", dependencies: ["CountdownKit"]),
        .testTarget(name: "CountdownKitTests", dependencies: ["CountdownKit"]),
        .testTarget(name: "DesignTokensTests", dependencies: ["DesignTokens"]),
    ]
)
