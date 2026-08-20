import SwiftUI
import CountdownKit
import DesignTokens

/// 价值时刻的登录引导（需求文档 5.14.1 / auth 原型 ACCOUNT/00）。
///
/// # 规则
/// - **底部浮层，不是全屏页** —— 不打断当前场景。
/// - 必须有「以后再说」，且点背景可关闭。
/// - 文案针对触发点定制，**不用通用的「登录同步」话术**：
///   说用户会失去什么，不说产品能提供什么。
///
/// # 这个视图永远不会出现在首次启动引导里
/// 设计决策 D-10。引导流程不 import Auth 模块，物理上拿不到它。
struct AuthPromptSheet: View {

    let trigger: AuthPromptTrigger
    /// 最近一封信要存多少天 —— 用于 `.firstLetter` 的定制文案。
    let letterDays: Int
    let palette: Palette
    let onBind: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .dsFont(DSFont.title(17))
                .foregroundStyle(palette.textPrimary.color)

            Text(subtitle)
                .dsFont(DSFont.caption(12.5))
                .foregroundStyle(palette.textSecondary.color)
                .lineSpacing(4)
                .padding(.top, DSSpacing.sm + 1)

            VStack(spacing: DSSpacing.cardGapWide) {
                DSPrimaryButtonLike(title: Strings.Auth.Prompt.bindNow, palette: palette,
                                    enabled: true, action: onBind)
                // 用「以后再说」不用「跳过」—— 后者暗示这是流程的一步。
                Button(action: onLater) {
                    Text(Strings.Auth.Prompt.later)
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textSecondary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, DSSpacing.lg)
        }
        .padding(.horizontal, DSSpacing.lg + 2)
        .padding(.top, DSSpacing.lg + 4)
        .padding(.bottom, DSSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface.color)
    }

    /// 只有「写完第一封信」这个触发点有资料给定的文案。
    /// 其余三个触发点的定制文案尚未提供，走占位符 —— **不自拟**。
    private var title: String {
        switch trigger {
        case .firstLetter: return Strings.Auth.Prompt.firstLetterTitle(days: letterDays)
        case .sevenDays:   return Strings.Auth.Prompt.sevenDaysTitle
        case .export:      return Strings.Auth.Prompt.exportTitle
        case .postExam:    return Strings.Auth.Prompt.postExamTitle
        }
    }

    private var subtitle: String {
        switch trigger {
        case .firstLetter: return Strings.Auth.Prompt.firstLetterSubtitle
        case .sevenDays:   return Strings.Auth.Prompt.sevenDaysSubtitle
        case .export:      return Strings.Auth.Prompt.exportSubtitle
        case .postExam:    return Strings.Auth.Prompt.postExamSubtitle
        }
    }
}
