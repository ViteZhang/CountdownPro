import Foundation

/// 皮肤（需求文档 5.9）。
///
/// **按累计打卡天数解锁，全部免费，不做付费皮肤。**
/// 皮肤同时作用于首页、小组件、分享卡片。
public enum Skin: Int, CaseIterable, Sendable, Identifiable {
    case `default` = 0
    case second = 1
    case third = 2
    case fourth = 3

    public var id: Int { rawValue }

    /// 解锁所需的累计打卡天数（5.9 表格）。
    public var unlockAtCheckInDays: Int {
        switch self {
        case .default: return 0
        case .second:  return 30
        case .third:   return 100
        case .fourth:  return 200
        }
    }

    public func isUnlocked(totalCheckIns: Int) -> Bool {
        totalCheckIns >= unlockAtCheckInDays
    }

    /// 该皮肤的配色是否已定义。
    ///
    /// 目前只有第一套有资料（设计系统 1.1）。第 2/3/4 套的配色**未定义**，
    /// 在拿到配色前这些皮肤不会出现在设置页，也不会因解锁而提示 ——
    /// 解锁逻辑本身已完整实现并有测试覆盖，补上配色即可生效。
    public var hasDefinedPalette: Bool { self == .default }

    /// 已可用于展示的皮肤。
    public static var available: [Skin] { allCases.filter(\.hasDefinedPalette) }

    /// 在 `totalCheckIns` 这一刻**刚刚**解锁的皮肤（用于轻量提示，不做弹窗打断）。
    public static func newlyUnlocked(totalCheckIns: Int) -> Skin? {
        allCases.first { $0.unlockAtCheckInDays == totalCheckIns && $0 != .default }
    }
}

public enum DSColorScheme: Sendable {
    case dark
    case light
}

extension Skin {
    /// 取该皮肤在指定模式下的色板。未定义配色的皮肤回落到默认皮肤。
    public func palette(_ scheme: DSColorScheme) -> Palette {
        guard hasDefinedPalette else { return Skin.default.palette(scheme) }
        switch scheme {
        case .dark:  return .defaultDark
        case .light: return .defaultLight
        }
    }
}

extension Palette {
    /// 设计系统 1.1「深色（主）」
    public static let defaultDark = Palette(
        background:    DSColor(0x101114),  // 近黑、微冷。不用 #000
        surface:       DSColor(0x1A1C21),
        surfaceRaised: DSColor(0x23262C),
        line:          DSColor(0x2E323A),
        textPrimary:   DSColor(0xF2F4F7),  // 不用纯白
        textSecondary: DSColor(0x8E96A3),
        textTertiary:  DSColor(0x5D646F),
        tree:          DSColor(0x7FA08A),  // 全界面唯一彩色
        warning:       DSColor(0xD9A05B),
        danger:        DSColor(0xC97064)   // 来源：countdown-app-auth.html
    )

    /// 设计系统 1.1「浅色」
    public static let defaultLight = Palette(
        background:    DSColor(0xFAFAF8),  // 纸白，非纯白
        surface:       DSColor(0xFFFFFF),
        surfaceRaised: DSColor(0xF2F1ED),
        line:          DSColor(0xE3E2DD),
        textPrimary:   DSColor(0x16181C),
        textSecondary: DSColor(0x6E6E68),
        textTertiary:  DSColor(0x9A9A94),
        tree:          DSColor(0x5E8570),
        warning:       DSColor(0xA9722C),
        danger:        DSColor(0xA8483C)   // 来源：countdown-app-auth.html
    )
}
