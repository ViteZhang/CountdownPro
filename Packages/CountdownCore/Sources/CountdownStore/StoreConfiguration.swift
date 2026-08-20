import Foundation

/// 持久化配置。
///
/// # 为什么必须走 App Group
/// 小组件是本产品**最重要的触达通道**（需求文档 5.10）——
/// 高中生在校瞄一眼锁屏不算"玩手机"。小组件必须能在**完全离线、零服务器依赖**的前提下
/// 读到考试与打卡数据，所以 SwiftData 的存储文件放在 App Group 容器里，
/// 主 App 读写、Widget Extension 只读。
public struct StoreConfiguration: Sendable {

    /// App Group 标识。Xcode 工程的 App 与 Widget 两个 target 都要开启这个能力。
    public let appGroupIdentifier: String

    /// SwiftData 存储文件名
    public let storeFileName: String

    /// 同考人数缓存的 UserDefaults key（存在同一个 App Group 里）。
    ///
    /// 缓存缺失 / 过期 / 低于 1 万都表现为「无值」，中号小组件与首页
    /// 据此**整块隐藏**该模块，不显示错误态、不显示占位骨架（5.7 / D-09）。
    public let censusCacheKey: String

    public init(
        appGroupIdentifier: String,
        storeFileName: String = "CountdownPro.store",
        censusCacheKey: String = "census.today"
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.storeFileName = storeFileName
        self.censusCacheKey = censusCacheKey
    }

    /// 全 App 共用的配置。
    ///
    /// `appGroupIdentifier` 必须与 App target 和 Widget target 的
    /// App Groups entitlement 完全一致，否则小组件读不到数据（表现为永远的占位态）。
    ///
    /// 注：产品名尚未拍板（需求文档待决事项 1），这里的标识符是按仓库名取的，
    /// 定名后需同步修改 entitlements、Bundle ID 与本行。
    public static let shared = StoreConfiguration(
        appGroupIdentifier: "group.com.countdownpro.shared"
    )

    public var containerURL: URL? {
        #if canImport(Darwin)
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        #else
        return nil
        #endif
    }

    public var storeURL: URL? {
        containerURL?.appendingPathComponent(storeFileName)
    }
}
