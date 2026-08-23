import SwiftUI
import UIKit
import CountdownKit
import DesignTokens

/// 心理支持资源。
///
/// # 号码是权威来源，不许改
/// - **12356**：国家卫生健康委协调工业和信息化部设置的全国统一心理援助热线。
/// - **12355**：共青团中央设立的青少年服务台，含心理咨询与法律援助。
///
/// 这两个号码和它们的主办单位**不是文案，是事实**。
/// 改一个数字的代价不是文案不好看，是一个真的很难熬的人打过去没人接。
/// 有测试盯着（`testHotlineNumbersAreTheOfficialOnes`）。
///
/// # 这一页刻意不做的事
/// - **不做情绪评估、量表、问卷。** 我们没有资质做心理筛查，
///   而一份看起来很专业的量表会让用户以为它有诊断意义。
/// - **不接入任何第三方心理咨询商业服务。** 在这个场景里做转化是不可原谅的。
/// - **不做二次确认弹窗。** 点了号码就直接拨 ——
///   一个已经很难开口的人，不该在最后一步再被问一次"确定吗"。
/// - **不写「24 小时」。** 国家卫生健康委的要求是每个设区的市每日不少于 18 小时，
///   各地实际时长并不统一。写死会让一个半夜打不通的人以为是自己的问题。
struct MentalHealthView: View {

    @Environment(\.theme) private var theme
    private var palette: Palette { theme.palette }

    var body: some View {
        SettingsPage(title: Strings.MentalHealth.title, palette: palette) {
            Text(Strings.MentalHealth.intro)
                .dsFont(DSFont.body(DSType.bodyLarge))
                .foregroundStyle(palette.textPrimary.color)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, DSSpacing.sm)

            SettingsGroup(palette: palette) {
                hotline(number: Strings.MentalHealth.hotlineNationalNumber,
                        caption: Strings.MentalHealth.hotlineNationalCaption)
                Divider().overlay(palette.line.color)
                hotline(number: Strings.MentalHealth.hotlineYouthNumber,
                        caption: Strings.MentalHealth.hotlineYouthCaption)
            }

            Text(Strings.MentalHealth.footnote)
                .dsFont(DSFont.caption(DSType.caption))
                .foregroundStyle(palette.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DSSpacing.sm)
        }
    }

    /// 一条热线。整行可点，点击直接调起拨号盘。
    private func hotline(number: String, caption: String) -> some View {
        Button {
            call(number)
        } label: {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(number)
                    // 号码本身就是这一页的主体，用大号字。不加图标、不加彩色。
                    .dsFont(DSFont.title(DSType.question))
                    .foregroundStyle(palette.textPrimary.color)
                Text(caption)
                    .dsFont(DSFont.caption(DSType.caption))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.md + 2)
            .padding(.vertical, DSSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(number)，\(caption)")
    }

    private func call(_ number: String) {
        guard let url = URL(string: "tel://\(number)") else { return }
        UIApplication.shared.open(url)
    }
}
