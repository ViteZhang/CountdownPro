import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// 视图层拿到的唯一样式入口。
///
/// # 硬约束
/// 视图层**只能**引用 token，禁止字面量颜色值和 magic number 尺寸。
/// 视觉后续会用 Claude Design 精修，改动必须只发生在 DesignTokens 这一层。
///
/// # 交接时最容易被改错的地方（设计系统第四部分）
/// 1. 有人会建议加「连续打卡」—— 见 D-03。数据层根本不提供 streak 查询。
/// 2. 有人会建议树能浇水互动 —— 见 D-05。`GrowthStage.stage` 的签名里没有打卡数。
/// 3. 有人会建议分享卡加二维码 —— 见 D-11。无码的品牌识别全靠「已走过」进度条。
/// 4. 有人会建议加班级榜 / 好友对比 —— 见 D-13。
/// 5. 有人会建议同考人数取整放大 —— 见 D-09。`CensusFormatter` 低于 1 万返回 nil。
/// 6. 有人会建议备考期加激励视频广告 —— 见 D-12。
/// 7. 有人会建议把登录提到首启第一屏 —— 见 D-10。注册率会涨，留存会崩。
///
/// 这七条每一条都合理，每一条都会让产品变成它试图区别于的那个东西。
public struct Theme: Equatable, Sendable {
    public let skin: Skin
    public let scheme: DSColorScheme
    public let palette: Palette

    public init(skin: Skin = .default, scheme: DSColorScheme = .dark) {
        self.skin = skin
        self.scheme = scheme
        self.palette = skin.palette(scheme)
    }
}

#if canImport(SwiftUI)
private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}

extension EnvironmentValues {
    public var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    /// 在根视图注入主题。深浅色跟随系统（设置页条目清单里没有主题切换项）。
    public func dsTheme(skin: Skin, colorScheme: ColorScheme) -> some View {
        environment(\.theme, Theme(skin: skin, scheme: colorScheme == .dark ? .dark : .light))
    }

    /// 应用一个字体规格：字号、字重、字距、动态字体上限一次性设好。
    public func dsFont(_ spec: DSFontSpec) -> some View {
        modifier(DSFontModifier(spec: spec))
    }
}

private struct DSFontModifier: ViewModifier {
    let spec: DSFontSpec

    func body(content: Content) -> some View {
        let base = content
            .font(spec.font)
            .tracking(spec.tracking)
        // 大数字设动态字体上限，否则进度环中心数字在 AX5 下会撑爆环。
        return Group {
            if spec.allowsUnboundedScaling {
                base
            } else {
                base.dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
    }
}

extension Shape {
    /// 统一 0.5pt 描边
    public func dsHairline(_ color: DSColor) -> some View {
        stroke(color.color, lineWidth: DSStroke.hairline)
    }
}
#endif
