// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CountdownCore",
    // macOS 平台必须显式声明：否则 `swift test` 拿到 SPM 默认的老部署目标
    // （macOS 10.13），Task / Date.now 等 API 全部不可用，测试编译失败。
    // .v14（Sonoma）与 .iOS(.v17) 同代，API 可用面一致。
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // 纯 Foundation：领域模型、日期计算、文案。App 与 Widget 共用，可在任意平台跑测试。
        .library(name: "CountdownKit", targets: ["CountdownKit"]),
        // 设计代币层。视图层唯一允许引用的样式来源。
        .library(name: "DesignTokens", targets: ["DesignTokens"]),
        // SwiftData 持久化 + 仓储。
        .library(name: "CountdownStore", targets: ["CountdownStore"]),
        // App 与 Widget 共用的视图组件（环 / 进度条 / 树）。
        .library(name: "CountdownUI", targets: ["CountdownUI"]),
    ],
    targets: [
        .target(name: "CountdownKit"),
        .target(name: "DesignTokens", dependencies: ["CountdownKit"]),
        .target(name: "CountdownStore", dependencies: ["CountdownKit"]),
        .target(name: "CountdownUI", dependencies: ["CountdownKit", "DesignTokens"]),
        .testTarget(name: "CountdownKitTests", dependencies: ["CountdownKit"]),
        .testTarget(name: "DesignTokensTests", dependencies: ["DesignTokens"]),
    ]
)
