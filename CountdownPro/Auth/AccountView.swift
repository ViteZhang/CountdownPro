import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens

/// 账号页（auth 原型 ACCOUNT/07）。
struct AccountView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Query private var accounts: [Account]

    @State private var showingDelete = false
    @State private var toast: String?

    private let cal = DayCalendar.current
    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }
    private var account: Account? { accounts.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Strings.Auth.accountTitle)
                .dsFont(DSFont.title(DSType.screenTitle))
                .foregroundStyle(palette.textPrimary.color)
                .padding(.top, DSSpacing.sm + 2)

            VStack(spacing: DSSpacing.cardGap) {
                infoRow(Strings.Auth.rowBindType, value: bindTypeName)
                infoRow(Strings.Auth.rowPhone, value: account?.phoneLastFour.map { "**** \($0)" }
                                                     ?? Strings.Auth.rowPhoneUnbound)
                actionRow(Strings.Auth.rowSyncNow, trailing: Strings.Auth.justNow) {
                    // 同步失败不得阻塞任何功能：静默重试，不弹错误。
                    toast = Strings.Auth.synced
                }
                // **即使有账号也必须提供导出**（5.13）。用户应能把自己的记录带走。
                actionRow(Strings.Auth.rowExport, trailing: "›") {
                    toast = Strings.Auth.exportedJSON
                }
                actionRow(Strings.Auth.rowSignOut, trailing: "›") {
                    toast = Strings.Auth.signedOut
                }
                // 注销入口用警示色，但**不隐藏、不埋深**（法规硬性要求，商店审核会专门查）。
                actionRow(Strings.Auth.rowDeleteAccount, trailing: "›",
                          tint: palette.danger) { showingDelete = true }
            }
            .padding(.top, DSSpacing.lg + 4)

            // 同步状态常驻可见，让用户确认数据安全。
            Text(Strings.Auth.lastSynced(lastSyncedText))
                .dsFont(DSFont.caption(11.5))
                .foregroundStyle(palette.textTertiary.color)
                .frame(maxWidth: .infinity)
                .padding(.top, DSSpacing.lg - 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
        .background(palette.background.color.ignoresSafeArea())
        .fullScreenCover(isPresented: $showingDelete) {
            DeleteAccountView(palette: palette) {
                toast = Strings.Auth.deleteSubmitted
            }
        }
        .overlay(alignment: .top) { toastView }
    }

    private var bindTypeName: String {
        switch account?.bindType {
        case .wechat: return "微信"
        case .qq:     return "QQ"
        case .apple:  return "Apple"
        case .phone:  return "手机号"
        case nil:     return Strings.Auth.rowPhoneUnbound
        }
    }

    private var lastSyncedText: String {
        guard let date = account?.lastSyncAt else { return Strings.Auth.justNow }
        return DateDisplay(cal: cal).short(date)
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).dsFont(DSFont.body(DSType.body))
                .foregroundStyle(palette.textPrimary.color)
            Spacer()
            Text(value).dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
        }
        .padding(.horizontal, DSSpacing.md + 3)
        .padding(.vertical, DSSpacing.md + 2)
        .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DSRadius.field + 1))
    }

    private func actionRow(_ title: String, trailing: String,
                           tint: DSColor? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).dsFont(DSFont.body(DSType.body))
                    .foregroundStyle((tint ?? palette.textPrimary).color)
                Spacer()
                Text(trailing).dsFont(DSFont.caption(13))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .padding(.horizontal, DSSpacing.md + 3)
            .padding(.vertical, DSSpacing.md + 2)
            .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DSRadius.field + 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .dsFont(DSFont.caption(12.5))
                .foregroundStyle(palette.textPrimary.color)
                .padding(.horizontal, DSSpacing.lg - 4)
                .padding(.vertical, DSSpacing.sm + 2)
                .background(palette.surfaceRaised.color, in: Capsule())
                .task {
                    try? await Task.sleep(for: .seconds(DSMotion.toast.seconds))
                    self.toast = nil
                }
        }
    }
}

/// 注销确认（auth 原型 ACCOUNT/08）。
///
/// # 不做挽留
/// **不做挽留弹窗、不做「确定要走吗」二次劝阻** ——
/// 注销权是法定权利，设置阻碍会被判定为违规。
struct DeleteAccountView: View {

    let palette: Palette
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var acknowledged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(palette.textSecondary.color)
                }
                .buttonStyle(.plain)
                Text(Strings.Auth.deleteNavTitle)
                    .dsFont(DSFont.body(DSType.body))
                    .foregroundStyle(palette.textPrimary.color)
                Spacer()
            }
            .frame(height: 52)

            Text(Strings.Auth.deleteTitle)
                .dsFont(DSFont.title(DSType.question - 1))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Auth.deleteSubtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.cardGapWide)

            // 必须逐条告知后果。
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                ForEach(Array(Strings.Auth.deleteConsequences.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(palette.danger.color)
                            .frame(width: 3.5, height: 3.5)
                            .padding(.top, 7)
                        Text(line)
                            .dsFont(DSFont.caption(12.5))
                            // 「未开启的信件将永久丢失」是最重要的一条，必须用强调色。
                            .foregroundStyle(index == Strings.Auth.deleteEmphasizedIndex
                                             ? palette.danger.color : palette.textSecondary.color)
                            .lineSpacing(5)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(DSSpacing.md + 2)
            .background {
                RoundedRectangle(cornerRadius: DSRadius.field).dsHairline(palette.danger)
            }
            .padding(.top, DSSpacing.lg + 6)

            Button { acknowledged.toggle() } label: {
                HStack(alignment: .top, spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DSRadius.checkbox)
                            .stroke(acknowledged ? palette.textPrimary.color : palette.textTertiary.color,
                                    lineWidth: 1)
                            .frame(width: 17, height: 17)
                        if acknowledged {
                            RoundedRectangle(cornerRadius: DSRadius.checkbox)
                                .fill(palette.textPrimary.color)
                                .frame(width: 17, height: 17)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(palette.background.color)
                        }
                    }
                    Text(Strings.Auth.deleteConfirmCheckbox)
                        .dsFont(DSFont.caption(11.5))
                        .foregroundStyle(palette.textTertiary.color)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, DSSpacing.lg + 4)

            Spacer(minLength: 0)

            VStack(spacing: DSSpacing.md) {
                // 描边警示色，**不用实心红** —— 不制造惊吓。
                Button {
                    onSubmitted()
                    dismiss()
                } label: {
                    Text(Strings.Auth.deleteConfirmButton)
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.danger.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md + 2)
                        .background {
                            RoundedRectangle(cornerRadius: DSRadius.button).dsHairline(palette.danger)
                        }
                }
                .buttonStyle(.plain)
                .opacity(acknowledged ? 1 : 0.3)
                .disabled(!acknowledged)

                Text(Strings.Auth.deleteFootnote)
                    .dsFont(DSFont.caption(DSType.captionSmall))
                    .foregroundStyle(palette.textTertiary.color)
            }
            .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
        .background(palette.background.color.ignoresSafeArea())
    }
}
