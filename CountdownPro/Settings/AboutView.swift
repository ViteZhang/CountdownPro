import SwiftUI
import CountdownKit
import DesignTokens

/// 关于页（《V1 剩余页面》第五节）。
///
/// # 三项容易被漏掉、且缺失会导致下架或整改的合规项
/// 1. **个人信息收集清单** —— 逐项列出收集了什么、用途、场景、是否必需。
///    本产品实际只有手机号 / 第三方 openid、设备标识（会话管理）、年龄布尔值三项，
///    清单很短，但必须有。
/// 2. **第三方信息共享清单** —— 每个 SDK 的提供方、收集的信息类型、用途、隐私政策链接。
///    **每接入一个新 SDK 就要更新这份清单。**
/// 3. **ICP 备案号** —— App 内需可查见，通常在关于页底部，可跳工信部查询。
///
/// # 四份正文是草案
/// 见 `LegalText`：开发方按 App 的实际行为写了一份底稿，每一份都顶着
/// 「草案…不得作为正式版本发布」，主体信息、联系方式、备案号仍是占位符。
///
/// 底稿必须由律师或合规顾问审核后才能上线。一份读起来很像的文本直接上线，
/// 是这个页面上唯一真正危险的做法 —— 它会让所有人（包括我们自己）
/// 以为这件事已经做完了。所以草案横幅写在**正文里**，不是写在注释里：
/// 删掉它是一个显眼的、需要解释的动作。
struct AboutView: View {

    @Environment(\.theme) private var theme
    private var palette: Palette { theme.palette }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return Strings.About.version(marketing, build)
    }

    var body: some View {
        SettingsPage(title: Strings.About.title, palette: palette) {
            // 应用名。取 `Strings.productName` 而不是读 Info.plist ——
            // 桌面图标下面那个名字由 Xcode 配置决定，这里显示的必须和它是同一个来源，
            // 否则改名时只会有一边跟着变。
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(Strings.productName)
                    .dsFont(DSFont.title(DSType.screenTitle))
                    .foregroundStyle(palette.textPrimary.color)
                Text(versionText)
                    .dsFont(DSFont.caption(DSType.caption))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .padding(.vertical, DSSpacing.md)

            SettingsGroup(palette: palette) {
                link(Strings.About.termsOfService, body: Strings.About.termsBody)
                Divider().overlay(palette.line.color)
                link(Strings.About.privacyPolicy, body: Strings.About.privacyBody)
                Divider().overlay(palette.line.color)
                link(Strings.About.personalInfoCollected, body: Strings.About.personalInfoBody)
                Divider().overlay(palette.line.color)
                link(Strings.About.thirdPartySharing, body: Strings.About.thirdPartyBody)
            }

            SettingsGroup(palette: palette) {
                link(Strings.About.feedback, body: Strings.About.feedbackContact)
            }

            // ICP 备案号常驻底部。
            Text(Strings.About.icpNumber)
                .dsFont(DSFont.caption(DSType.footnote))
                .foregroundStyle(palette.textTertiary.color)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, DSSpacing.xl)
        }
    }

    private func link(_ title: String, body: String) -> some View {
        NavigationLink {
            SettingsPage(title: title, palette: palette) {
                // 法务文本是几千字的长文，行距不给够就没人读得下去 ——
                // 而"没人读得下去"正是这类文本被写成天书的原因，不该由我们再添一笔。
                Text(body)
                    .dsFont(DSFont.body(DSType.body))
                    .foregroundStyle(palette.textSecondary.color)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } label: {
            SettingsRow(title: title, palette: palette)
        }
        .buttonStyle(.plain)
    }
}
