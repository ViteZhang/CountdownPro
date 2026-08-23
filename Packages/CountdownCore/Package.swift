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
        // 树的七张美术资产随包分发，App 与 Widget 因此共用同一份 —— 
        // 复制到两个 target 里迟早会更新一份忘一份。
        //
        // 用 `.copy` 而不是 `.process`：`.copy` 保证 bundle 里就是
        // `Tree/seed.png` 这个路径，一字不差；`.process` 会不会把子目录压平
        // 是 SwiftPM 的实现细节，两种结果都出现过。资产读不出来时页面只是
        // 空白（`Image` 找不到名字不会报错），这类 bug 没人会怀疑到构建规则头上，
        // 所以这里选那个路径确定的规则，读取端也按确定路径取（见 TreeView）。
        .target(
            name: "CountdownUI",
            dependencies: ["CountdownKit", "DesignTokens"],
            resources: [.copy("Resources/Tree")]
        ),
        .testTarget(name: "CountdownKitTests", dependencies: ["CountdownKit"]),
        .testTarget(name: "DesignTokensTests", dependencies: ["DesignTokens"]),
    ]
)
