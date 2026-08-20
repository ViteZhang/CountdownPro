import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens

/// 根视图。
///
/// # 这个文件以及整条引导路径不得 import 任何账号 / 登录模块
/// 设计决策 D-10：**首次启动引导中不得出现任何登录入口。**
/// 注册墙出现在用户还没获得任何价值的那一刻，会砍掉大量首启转化，
/// 而这个人群对"要注册"格外反感。物理隔离比口头约定可靠 ——
/// 想在引导里加登录，得先加一个 import，那一行会在 review 里很显眼。
struct RootView: View {

    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<Exam> { $0.isPrimary }, sort: \Exam.createdAt)
    private var primaryExams: [Exam]

    var body: some View {
        Group {
            if let exam = primaryExams.first {
                // 底部 Tab 三项（信息架构第 3 章）。记录 / 信箱在开发顺序 5 接入。
                TabView {
                    HomeView(exam: exam)
                        .tabItem { Label(Strings.Tab.home, systemImage: "clock") }
                    Text(Strings.missing("记录页（开发顺序 5）"))
                        .tabItem { Label(Strings.Tab.log, systemImage: "calendar") }
                    Text(Strings.missing("信箱（开发顺序 5）"))
                        .tabItem { Label(Strings.Tab.letters, systemImage: "envelope") }
                }
            } else {
                // 首次启动引导（开发顺序 4）
                Text(Strings.missing("首次启动引导（开发顺序 4）"))
            }
        }
        .dsTheme(skin: .default, colorScheme: colorScheme)
    }
}
