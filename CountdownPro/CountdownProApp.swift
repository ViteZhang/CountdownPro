import SwiftUI
import SwiftData
import CountdownStore

@main
struct CountdownProApp: App {

    /// 容器放 App Group，小组件读同一份数据（需求文档 5.10）。
    @State private var container = ModelContainerFactory.makeAppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
