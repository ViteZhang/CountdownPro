import WidgetKit
import SwiftUI
import CountdownKit
import DesignTokens

/// 四种小组件（需求文档 5.10）。**优先级等同首页。**
///
/// 「小组件添加率」是最关键的健康指标 —— 低于 30% 说明核心机制失效（第 8 章）。
@main
struct CountdownWidgetBundle: WidgetBundle {
    var body: some Widget {
        SmallCountdownWidget()
        MediumCountdownWidget()
        CircularCountdownWidget()
        RectangularCountdownWidget()
    }
}

struct SmallCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CountdownSmall", provider: CountdownProvider()) { entry in
            SmallWidgetView(entry: entry).containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName(Strings.Widget.smallDisplayName)
        .description(Strings.Widget.widgetDescription)
        .supportedFamilies([.systemSmall])
    }
}

struct MediumCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CountdownMedium", provider: CountdownProvider()) { entry in
            MediumWidgetView(entry: entry).containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName(Strings.Widget.mediumDisplayName)
        .description(Strings.Widget.widgetDescription)
        .supportedFamilies([.systemMedium])
    }
}

struct CircularCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CountdownCircular", provider: CountdownProvider()) { entry in
            CircularWidgetView(entry: entry).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(Strings.Widget.circularDisplayName)
        .description(Strings.Widget.widgetDescription)
        .supportedFamilies([.accessoryCircular])
    }
}

struct RectangularCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CountdownRectangular", provider: CountdownProvider()) { entry in
            RectangularWidgetView(entry: entry).containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName(Strings.Widget.rectangularDisplayName)
        .description(Strings.Widget.widgetDescription)
        .supportedFamilies([.accessoryRectangular])
    }
}

/// 桌面小组件的底色。设计决策 D-07：不用纯黑。
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light)
            .palette.background.color
    }
}
