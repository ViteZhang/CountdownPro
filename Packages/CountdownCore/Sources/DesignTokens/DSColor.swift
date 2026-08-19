import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// 一个色值。
///
/// 故意存 hex 而非直接存 `Color`：分享卡导出（`ImageRenderer`）、小组件、以及
/// 未来的服务端预览都需要拿到原始值，而且 hex 可以在任意平台被测试断言。
public struct DSColor: Equatable, Hashable, Sendable {
    public let hex: UInt32

    public init(_ hex: UInt32) { self.hex = hex }

    public var red: Double   { Double((hex >> 16) & 0xFF) / 255 }
    public var green: Double { Double((hex >> 8) & 0xFF) / 255 }
    public var blue: Double  { Double(hex & 0xFF) / 255 }

    public var hexString: String { String(format: "#%06X", hex) }

    /// 相对亮度（WCAG）。用于自检两套模式的对比度。
    public var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    public func contrastRatio(against other: DSColor) -> Double {
        let a = relativeLuminance, b = other.relativeLuminance
        let (hi, lo) = a > b ? (a, b) : (b, a)
        return (hi + 0.05) / (lo + 0.05)
    }
}

#if canImport(SwiftUI)
extension DSColor {
    public var color: Color { Color(red: red, green: green, blue: blue) }
}
#endif

/// 一套完整语义色板。
///
/// 设计系统 1.1 的规则：**两套模式是同一个性格的一日两态，不是两套设计。**
/// 任何新增颜色都必须同时在两套里成立 —— 结构上强制：`Palette` 的每个字段
/// 在 `.dark` 与 `.light` 里都必须有值，少写一个编译不过。
public struct Palette: Equatable, Sendable {

    /// 基底。设计决策 D-07：**不用 `#000`。**
    /// 三个理由：纯黑在 OLED 上滚动拖影；`#000` 配 `#FFF` 对比度 21:1，
    /// 中文笔画密集会产生光晕；纯黑没有"更深"的余地，层级只能往亮里走。
    public let background: DSColor
    public let surface: DSColor
    /// 分段控件选中态、Toast
    public let surfaceRaised: DSColor
    /// 描边 / 进度轨道。描边统一 0.5pt。
    public let line: DSColor
    /// 主文字 / 进度填充。设计决策 D-07：**不用纯白。**
    public let textPrimary: DSColor
    public let textSecondary: DSColor
    public let textTertiary: DSColor
    /// 树。设计决策 D-06：**全界面唯一彩色。**
    /// 每多一个彩色元素，树的焦点性就削弱一分。新增任何彩色前先读 D-06。
    public let tree: DSColor
    /// 警示。**仅用于表单校验。**
    public let warning: DSColor
    /// 危险（注销流程）。
    /// 注意：设计系统 1.1 的色板**没有收录这一项**，值取自 countdown-app-auth.html。
    public let danger: DSColor

    public init(
        background: DSColor, surface: DSColor, surfaceRaised: DSColor, line: DSColor,
        textPrimary: DSColor, textSecondary: DSColor, textTertiary: DSColor,
        tree: DSColor, warning: DSColor, danger: DSColor
    ) {
        self.background = background
        self.surface = surface
        self.surfaceRaised = surfaceRaised
        self.line = line
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.tree = tree
        self.warning = warning
        self.danger = danger
    }
}
