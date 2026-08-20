import WidgetKit
import SwiftUI
import CountdownKit
import CountdownUI
import DesignTokens

/// 锁屏组件（需求文档 5.10）。
///
/// # 系统会把锁屏组件去色
/// 所以**进度只能靠填充比例表达，不得依赖颜色区分**。
/// 这两个视图刻意不引用 `Palette` —— 全部走 `.primary` / `.tertiary` 这类层级色，
/// 交给系统的染色管线。引用了 palette 反而会在去色后变成一团同色。

// MARK: - 锁屏圆形

struct CircularWidgetView: View {
    let entry: CountdownEntry

    var body: some View {
        if let data = entry.data {
            // Gauge 是系统为 accessoryCircular 提供的原生形态，
            // 去色、Always-On 低亮度模式都由系统处理好。
            Gauge(value: data.countdown.progress) {
                EmptyView()
            } currentValueLabel: {
                Text(remainingText(data.countdown))
                    .dsFont(DSFont.body(15))
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            // 填充比例 = 已走过（D-01）。这里读出来的也必须是"已走过"，
            // 否则锁屏上的环和首页的环会朝相反方向走。
            .accessibilityLabel(Text(Strings.Home.passed(data.countdown.daysPassed)))
        } else {
            Image(systemName: "circle.dashed")
        }
    }
}

// MARK: - 锁屏矩形

/// 单行文字 + 细进度条（5.10）。
struct RectangularWidgetView: View {
    let entry: CountdownEntry

    var body: some View {
        if let data = entry.data {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(data.examTitle)
                        .dsFont(DSFont.caption(12))
                        .foregroundStyle(.secondary)
                    Text(remainingText(data.countdown))
                        .dsFont(DSFont.body(16))
                    if !data.countdown.isExamDay && !data.countdown.isAfterExam {
                        Text(Strings.Common.day)
                            .dsFont(DSFont.caption(12))
                            .foregroundStyle(.secondary)
                    }
                }

                DSAccessoryBar(progress: data.countdown.progress, height: 2)

                // D-01 在锁屏上同样成立。
                Text(Strings.Home.passed(data.countdown.daysPassed))
                    .dsFont(DSFont.caption(11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(Strings.Widget.notConfigured)
                .dsFont(DSFont.caption(12))
        }
    }
}
