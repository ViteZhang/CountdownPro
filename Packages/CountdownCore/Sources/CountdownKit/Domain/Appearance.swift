import Foundation

/// 深浅色偏好（《V1 剩余页面》2.1 行 3）。
///
/// 设置页给的是一个「跟随系统深浅色」开关，关掉之后才出现二选一 ——
/// 所以这里是三态，不是布尔值。做成布尔加一个"当开关关掉时用哪个"的第二个字段，
/// 会出现"跟随系统 + 记着深色"这种没有意义、但完全可能被写出来的组合。
public enum AppearancePreference: Int, CaseIterable, Sendable {
    case followSystem = 0
    case alwaysDark = 1
    case alwaysLight = 2

    public var followsSystem: Bool { self == .followSystem }

    /// 结合系统当前的模式，算出实际该用哪一套色板。
    ///
    /// - Parameter systemIsDark: 系统此刻是不是深色。
    public func resolvedIsDark(systemIsDark: Bool) -> Bool {
        switch self {
        case .followSystem: return systemIsDark
        case .alwaysDark:   return true
        case .alwaysLight:  return false
        }
    }
}
