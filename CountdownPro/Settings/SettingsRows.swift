import SwiftUI
import CountdownKit
import DesignTokens

/// 设置区域共用的行。
///
/// 抽出来不是为了少写几行，是为了让"行长什么样"只有一个答案 ——
/// 设置页、提醒页、外观页、关于页各自搓一套，几轮迭代后它们必然不一样，
/// 而这种不一样没有任何人是故意做的。
///
/// # 分组不加分组标题
/// 《V1 剩余页面》2.1：用间距分隔即可。加了标题这页会显得很"系统设置"，
/// 不符合产品调性 —— 这个 App 从头到尾在避免"工具感"。
struct SettingsGroup<Content: View>: View {
    let palette: Palette
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: DSStroke.hairline) {
            content
        }
        .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DSRadius.card,
                                                                style: .continuous))
    }
}

/// 一行：标题 + 右侧值 + 「›」。
struct SettingsRow: View {
    let title: String
    var value: String?
    var showsChevron = true
    let palette: Palette

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Text(title)
                .dsFont(DSFont.body(DSType.bodyLarge))
                .foregroundStyle(palette.textPrimary.color)
            Spacer(minLength: DSSpacing.sm)
            if let value {
                Text(value)
                    .dsFont(DSFont.body(DSType.body))
                    .foregroundStyle(palette.textSecondary.color)
                    .lineLimit(1)
            }
            if showsChevron {
                Text("›")
                    .dsFont(DSFont.body(DSType.bodyLarge))
                    .foregroundStyle(palette.textTertiary.color)
            }
        }
        .padding(.horizontal, DSSpacing.md + 2)
        .padding(.vertical, DSSpacing.md)
        .contentShape(Rectangle())
    }
}

/// 一行开关。可带副文案。
struct SettingsToggleRow: View {
    let title: String
    var caption: String?
    @Binding var isOn: Bool
    let palette: Palette

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.sm) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(title)
                    .dsFont(DSFont.body(DSType.bodyLarge))
                    .foregroundStyle(palette.textPrimary.color)
                if let caption {
                    Text(caption)
                        .dsFont(DSFont.caption(DSType.caption))
                        .foregroundStyle(palette.textSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DSSpacing.sm)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                // D-06：全界面灰阶。开关是系统控件，不给它染上第二个彩色。
                .tint(palette.textPrimary.color)
        }
        .padding(.horizontal, DSSpacing.md + 2)
        .padding(.vertical, DSSpacing.md - 2)
    }
}

/// 二级页统一的页面骨架：标题 + 内容 + 基底色。
struct SettingsPage<Content: View>: View {
    let title: String
    let palette: Palette
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                content
            }
            .padding(.horizontal, DSSpacing.pageHorizontalWide)
            .padding(.top, DSSpacing.md)
            .padding(.bottom, DSSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.background.color.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 一次性轻提示。
///
/// 解锁皮肤、主考试易主这类事情**只给 Toast，不做弹窗打断**（4.3 / 3.4）。
/// 它们是"顺带告诉你一声"，不是需要用户决策的事。
struct ToastOverlay: ViewModifier {
    @Binding var text: String?
    let palette: Palette

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let text {
                Text(text)
                    .dsFont(DSFont.body(DSType.caption))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.background.color)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .background(Capsule().fill(palette.textPrimary.color.opacity(0.92)))
                    .padding(.top, DSSpacing.lg)
                    .transition(.opacity)
                    .task(id: text) {
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation { self.text = nil }
                    }
            }
        }
    }
}

extension View {
    func dsToast(_ text: Binding<String?>, palette: Palette) -> some View {
        modifier(ToastOverlay(text: text, palette: palette))
    }
}
