import Foundation
import CountdownKit

#if canImport(SwiftData)
import SwiftData

/// 主 App 的 SwiftData 容器。
///
/// # 为什么放 App Group 而不是默认位置
/// 小组件必须能读到同一份数据（需求文档 5.10）。默认容器在 App 沙盒内，
/// Widget Extension 是另一个进程，读不到。
///
/// # 为什么允许降级到内存
/// **本地优先的底线是：存储出问题也不能让用户打不开 App。**
/// App Group 未配置（开发期常见）或磁盘异常时，退回内存容器，
/// 用户仍能完整使用当次会话 —— 与「同步失败不得阻塞任何功能」同一条原则。
public enum ModelContainerFactory {

    @MainActor
    public static func makeAppContainer(
        configuration: StoreConfiguration = .shared
    ) -> ModelContainer {
        let schema = Schema(ModelSchema.all)

        if let url = configuration.storeURL {
            let config = ModelConfiguration(url: url)
            if let container = try? ModelContainer(for: schema, configurations: config) {
                return container
            }
        }

        let fallback = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: fallback) else {
            // 连内存容器都建不起来意味着 schema 本身有问题，属于开发期错误。
            preconditionFailure("无法创建 ModelContainer，请检查 ModelSchema")
        }
        return container
    }

    /// 写入同考人数缓存，供小组件读取。
    ///
    /// 带日期戳，小组件只采用**今天**写入的值 —— 隔夜的数字不能拿来说
    /// 「今天有 X 万人和你一起」（D-09）。
    public static func cacheCensus(
        count: Int,
        at date: Date = .now,
        configuration: StoreConfiguration = .shared
    ) {
        guard let defaults = UserDefaults(suiteName: configuration.appGroupIdentifier) else { return }
        defaults.set(["count": count, "date": date], forKey: configuration.censusCacheKey)
    }
}
#endif
