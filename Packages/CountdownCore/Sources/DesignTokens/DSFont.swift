import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// 字体族。设计系统 1.2：**产品说话用无衬线，用户说话用衬线。**
///
/// 衬线只用于心里话和信件。这个区分要严格保持 —— 它让用户的文字在自己的 App 里显得郑重。
public enum DSFontFamily: Sendable {
    /// 界面：系统无衬线（PingFang SC / 系统默认）
    case ui
    /// **用户自己写的内容**：衬线（Songti SC / STSong）
    case userWritten

    public var postScriptNames: [String] {
        switch self {
        case .ui:          return []           // 走系统默认
        case .userWritten: return ["Songti SC", "STSong"]
        }
    }
}

/// 字号 → 字重的映射。设计系统 1.2 标记为**硬规则**。
///
/// 关键设计：字重**不由调用方指定**，由字号推导。
/// 这样"某处不小心用了细体的 11pt 中文"这类错误在类型层面就不可能发生 ——
/// 中文笔画密，深色底上细体会糊。
public enum DSFontWeight: Sendable {
    /// 设计系统 1.2 表格给了三档（≥32 / 14–20 / ≤12），
    /// 13pt 与 21–31pt 两个区间**表格未覆盖**，以下为实现约定：
    /// - 13pt 归入 400（原型里 13px 大量用作次文字，属正文体量）
    /// - 21–31pt 归入 300（大字过渡带，不该突然变回 400）
    public static func weight(forPointSize size: Double) -> Double {
        switch size {
        case ..<12.5:  return 500   // ≤12：中文笔画密，深色底上细体会糊
        case ..<20.5:  return 400   // 13–20
        case ..<32:    return 300   // 21–31（表格未覆盖，实现约定）
        default:       return 200   // ≥32：大数字用细体才有呼吸感
        }
    }

    /// 大数字统一负字距（设计系统 1.2：`-2px` 到 `-4px`）。
    ///
    /// 按字号比例插值后 clamp 到 [-4, -2]。
    /// 注：原型 milestone 大数字用了 `-6px`，超出设计系统给定区间，此处以设计系统为准。
    public static func tracking(forPointSize size: Double) -> Double {
        guard size >= 32 else { return 0 }
        return min(max(-size * 0.045, -4), -2)
    }
}

/// 一个字体规格。视图层只能通过 `DSFont` 的工厂方法拿到它。
public struct DSFontSpec: Equatable, Sendable {
    public let family: DSFontFamily
    public let size: Double
    public let weight: Double
    public let tracking: Double
    /// 该字号是否允许跟随动态字体无限放大。
    ///
    /// 大数字必须设上限：进度环中心数字在 AX5 下会把环撑爆。
    /// 这是需求文档「支持动态字体」与「进度环布局成立」之间唯一的冲突点，
    /// 处理方式集中在这里，视图层不再各自判断。
    public let allowsUnboundedScaling: Bool

    public init(family: DSFontFamily, size: Double) {
        self.family = family
        self.size = size
        self.weight = DSFontWeight.weight(forPointSize: size)
        self.tracking = DSFontWeight.tracking(forPointSize: size)
        self.allowsUnboundedScaling = size < 32
    }
}

public enum DSFont {
    // MARK: 界面（无衬线）

    /// 进度环中心 / 引导第 4 屏 / 分享卡的大数字。字重自动为 200，自动带负字距。
    public static func display(_ size: Double) -> DSFontSpec { DSFontSpec(family: .ui, size: size) }
    public static func title(_ size: Double) -> DSFontSpec { DSFontSpec(family: .ui, size: size) }
    public static func body(_ size: Double) -> DSFontSpec { DSFontSpec(family: .ui, size: size) }
    public static func caption(_ size: Double) -> DSFontSpec { DSFontSpec(family: .ui, size: size) }

    // MARK: 用户写的内容（衬线）

    /// 心里话与信件正文。**只有这两处允许用衬线。**
    public static func userWritten(_ size: Double) -> DSFontSpec {
        DSFontSpec(family: .userWritten, size: size)
    }
}

#if canImport(SwiftUI)
extension DSFontSpec {
    public var font: Font {
        switch family {
        case .ui:
            return .system(size: size, weight: Font.Weight.fromNumeric(weight))
        case .userWritten:
            // 找得到宋体就用宋体，找不到回落到系统衬线体
            if let name = family.postScriptNames.first(where: { UIFontExists(name: $0) }) {
                return .custom(name, size: size)
            }
            return .system(size: size, weight: Font.Weight.fromNumeric(weight), design: .serif)
        }
    }
}

extension Font.Weight {
    static func fromNumeric(_ w: Double) -> Font.Weight {
        switch w {
        case ..<250: return .ultraLight
        case ..<350: return .light
        case ..<450: return .regular
        default:     return .medium
        }
    }
}
#endif

#if canImport(UIKit)
import UIKit
func UIFontExists(name: String) -> Bool { UIFont(name: name, size: 12) != nil }
#else
func UIFontExists(name: String) -> Bool { false }
#endif
