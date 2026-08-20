import Foundation

/// 同步服务的抽象。
public protocol SyncService: Sendable {
    func push(_ snapshot: ExportSnapshot) async throws
    func pull() async throws -> ExportSnapshot?
}

/// 同步协调者。
///
/// # 唯一一条不可违背的规则
/// **同步失败不得阻塞任何功能**（5.14.4）。静默重试，不弹错误。
///
/// 所以这个类型的公开方法**没有一个会抛错** —— 调用方拿不到失败，
/// 也就无法在 UI 上把失败暴露出来。这不是偷懒，这是把约束写进类型里。
public actor SyncCoordinator {

    private let service: SyncService
    private var isRunning = false

    /// 静默重试的退避间隔（秒）。用完还失败就等下一次触发，不打扰用户。
    public static let backoffSeconds: [UInt64] = [2, 8, 30]

    public init(service: SyncService) {
        self.service = service
    }

    /// 上行合并。**永远不抛错、不返回失败。**
    public func sync(local: ExportSnapshot, now: Date) async -> ExportSnapshot {
        guard !isRunning else { return local }
        isRunning = true
        defer { isRunning = false }

        for delay in Self.backoffSeconds {
            do {
                let remote = try await service.pull()
                let merged = remote.map { MergeRules.merge(local: local, remote: $0, now: now) } ?? local
                try await service.push(merged)
                return merged
            } catch {
                // 静默。不冒泡到 UI。
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
        }
        // 全部失败也照常返回本地数据 —— **本地才是真相源。**
        return local
    }
}
