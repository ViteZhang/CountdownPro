import Foundation
import CountdownKit

/// 皮肤（需求文档 5.9）。
///
/// # 皮肤不是换主题色，是换基底色温
/// 四套全部维持「全界面灰阶 + 唯一彩色给树」（设计决策 D-06），
/// 区别只在于灰的冷暖倾向和树的色相。
///
/// 一旦某套皮肤引入第二个彩色，整套视觉体系就破了 —— 而且是不可逆的：
/// 用户见过一次带强调色的界面，再回到灰阶就会觉得"这套是不是没做完"。
///
/// # 按累计打卡天数解锁，全部免费
/// 皮肤是留存机制，不是变现机制。不做付费皮肤。
/// 未解锁的皮肤**正常展示且可预览**，只是不能应用 —— 看得到才有动力。
public enum Skin: Int, CaseIterable, Sendable, Identifiable {
    /// 深空（默认）
    case `default` = 0
    /// 晨雾 —— 暖中性灰
    case second = 1
    /// 夜潮 —— 偏蓝
    case third = 2
    /// 旧纸 —— 暖棕
    case fourth = 3

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .default: return Strings.Skins.deepSpace
        case .second:  return Strings.Skins.morningMist
        case .third:   return Strings.Skins.nightTide
        case .fourth:  return Strings.Skins.oldPaper
        }
    }

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

    /// 还差几天解锁。已解锁返回 0。
    public func daysUntilUnlock(totalCheckIns: Int) -> Int {
        max(0, unlockAtCheckInDays - totalCheckIns)
    }

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
    /// 取该皮肤在指定模式下的色板。
    public func palette(_ scheme: DSColorScheme) -> Palette {
        switch (self, scheme) {
        case (.default, .dark):  return .deepSpaceDark
        case (.default, .light): return .deepSpaceLight
        case (.second, .dark):   return .morningMistDark
        case (.second, .light):  return .morningMistLight
        case (.third, .dark):    return .nightTideDark
        case (.third, .light):   return .nightTideLight
        case (.fourth, .dark):   return .oldPaperDark
        case (.fourth, .light):  return .oldPaperLight
        }
    }
}

extension Palette {

    // MARK: - 警示色
    //
    // `warning`（表单校验）与 `danger`（注销流程）**四套皮肤共用**。
    //
    // 它们不是"装饰色"，是"这里出问题了"的信号。信号色跟着皮肤变，
    // 等于让用户每换一次皮肤就重新学一遍红色代表什么。
    // 而且它们出现的场景（验证码错了、要注销账号）都不该是"好看"的时刻。
    private static let warningDark  = DSColor(0xD9A05B)
    private static let warningLight = DSColor(0xA9722C)
    /// 来源：countdown-app-auth.html
    private static let dangerDark   = DSColor(0xC97064)
    private static let dangerLight  = DSColor(0xA8483C)

    // MARK: - 深空（默认，0 天解锁）— 设计系统 1.1

    /// 设计系统 1.1「深色（主）」
    public static let deepSpaceDark = Palette(
        background:    DSColor(0x101114),  // 近黑、微冷。不用 #000
        surface:       DSColor(0x1A1C21),
        surfaceRaised: DSColor(0x23262C),
        line:          DSColor(0x2E323A),
        textPrimary:   DSColor(0xF2F4F7),  // 不用纯白
        textSecondary: DSColor(0x8E96A3),
        textTertiary:  DSColor(0x5D646F),
        tree:          DSColor(0x7FA08A),  // 全界面唯一彩色
        warning:       warningDark,
        danger:        dangerDark
    )

    /// 设计系统 1.1「浅色」
    public static let deepSpaceLight = Palette(
        background:    DSColor(0xFAFAF8),  // 纸白，非纯白
        surface:       DSColor(0xFFFFFF),
        surfaceRaised: DSColor(0xF2F1ED),
        line:          DSColor(0xE3E2DD),
        textPrimary:   DSColor(0x16181C),
        textSecondary: DSColor(0x6E6E68),
        textTertiary:  DSColor(0x9A9A94),
        tree:          DSColor(0x5E8570),
        warning:       warningLight,
        danger:        dangerLight
    )

    // MARK: - 晨雾（累计 30 天解锁）— 暖中性灰

    public static let morningMistDark = Palette(
        background:    DSColor(0x131211),
        surface:       DSColor(0x1D1B19),
        surfaceRaised: DSColor(0x262320),
        line:          DSColor(0x363230),
        textPrimary:   DSColor(0xF5F2EE),
        textSecondary: DSColor(0x9C958C),
        textTertiary:  DSColor(0x6A645C),
        tree:          DSColor(0x93A07F),
        warning:       warningDark,
        danger:        dangerDark
    )

    public static let morningMistLight = Palette(
        background:    DSColor(0xFBF9F4),
        surface:       DSColor(0xFFFFFF),
        surfaceRaised: DSColor(0xF3F0E9),
        line:          DSColor(0xE5E0D6),
        textPrimary:   DSColor(0x1A1815),
        textSecondary: DSColor(0x706A61),
        textTertiary:  DSColor(0x9C968C),
        tree:          DSColor(0x6E7F5A),
        warning:       warningLight,
        danger:        dangerLight
    )

    // MARK: - 夜潮（累计 100 天解锁）— 偏蓝

    public static let nightTideDark = Palette(
        background:    DSColor(0x0D1016),
        surface:       DSColor(0x161A22),
        surfaceRaised: DSColor(0x1F242E),
        line:          DSColor(0x2A3140),
        textPrimary:   DSColor(0xEFF3F8),
        textSecondary: DSColor(0x8892A3),
        textTertiary:  DSColor(0x5A6373),
        // 这一套的树是唯一偏青的（色相约 196°，其余三套在 80–148°）。
        // 底色整体偏蓝，纯绿的树会从背景上"跳"出来显得贴片；
        // 往青里挪一点才和基底是同一个光源下的东西。
        // **但绝不能再往冷里走** —— 过了 200° 就读作蓝，树就不是树了。
        tree:          DSColor(0x6E93A0),
        warning:       warningDark,
        danger:        dangerDark
    )

    public static let nightTideLight = Palette(
        background:    DSColor(0xF8FAFB),
        surface:       DSColor(0xFFFFFF),
        surfaceRaised: DSColor(0xEEF2F5),
        line:          DSColor(0xDDE3E9),
        textPrimary:   DSColor(0x14181E),
        textSecondary: DSColor(0x68717D),
        textTertiary:  DSColor(0x97A0AB),
        tree:          DSColor(0x4E7684),
        warning:       warningLight,
        danger:        dangerLight
    )

    // MARK: - 旧纸（累计 200 天解锁）— 暖棕

    public static let oldPaperDark = Palette(
        background:    DSColor(0x14110E),
        surface:       DSColor(0x1E1A16),
        surfaceRaised: DSColor(0x28231D),
        line:          DSColor(0x38322A),
        textPrimary:   DSColor(0xF4F0E8),
        textSecondary: DSColor(0x9C9285),
        textTertiary:  DSColor(0x6B6255),
        // 基底是暖棕，树**仍然是橄榄绿**，不是褐色。
        // 把这一套的树改成褐色是最容易被提出的"提升协调性"意见，
        // 而枯褐色会被读作"树枯了" —— 直接违反 D-05（树只与时间有关，
        // 不因表现枯萎）。有一条测试盯着色相。
        tree:          DSColor(0x7E8A66),
        warning:       warningDark,
        danger:        dangerDark
    )

    public static let oldPaperLight = Palette(
        background:    DSColor(0xFAF7F0),
        surface:       DSColor(0xFFFDF8),
        surfaceRaised: DSColor(0xF1EDE2),
        line:          DSColor(0xE3DDCE),
        textPrimary:   DSColor(0x1C1813),
        textSecondary: DSColor(0x726A5C),
        textTertiary:  DSColor(0x9E9686),
        tree:          DSColor(0x64714E),
        warning:       warningLight,
        danger:        dangerLight
    )

    // MARK: - 旧名保留
    //
    // 一大批调用方写的是 `defaultDark` / `defaultLight`。皮肤从一套变成四套之后，
    // "default"这个词已经不再描述配色本身，而是描述"哪一套是默认的" ——
    // 这是两件会分开变的事（换默认皮肤是一个产品决策，改深空的色值是另一个）。
    public static var defaultDark: Palette { .deepSpaceDark }
    public static var defaultLight: Palette { .deepSpaceLight }
}
