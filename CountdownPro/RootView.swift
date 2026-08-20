import SwiftUI
import CountdownKit
import DesignTokens

/// 根视图。
///
/// 引导完成前进引导，完成后进主界面（Tab 三项：倒计时 / 记录 / 信箱）。
///
/// # 注意
/// **这个文件以及整条引导路径不得 import 任何账号 / 登录相关模块。**
/// 设计决策 D-10：首次启动引导中不得出现任何登录入口。
/// 用注册墙换来的注册率会涨，留存会崩。物理隔离比口头约定可靠。
struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // 首页 / 引导将在开发顺序 3、4 接入。
        Text(Strings.missing("根视图占位（开发顺序 3、4 接入）"))
            .dsTheme(skin: .default, colorScheme: colorScheme)
    }
}
