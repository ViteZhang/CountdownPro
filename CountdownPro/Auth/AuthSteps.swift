import SwiftUI
import CountdownKit
import DesignTokens

// MARK: - 登录方式（ACCOUNT/01）

struct LoginMethodStep: View {
    let palette: Palette
    let onPick: (LoginMethod) -> Void

    /// 已确认为企业主体；iOS 端一律带 Apple（审核指南 4.8）。
    private var methods: [LoginMethod] {
        LoginMethodPolicy.methods(platform: .iOS, entity: .business)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题是「保存你的记录」，不是「登录 / 注册」。
            Text(Strings.Auth.methodTitle)
                .dsFont(DSFont.title(DSType.question - 1))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Auth.methodSubtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .lineSpacing(4)
                .padding(.top, DSSpacing.cardGapWide)

            VStack(spacing: DSSpacing.cardGapWide) {
                ForEach(Array(methods.enumerated()), id: \.element.id) { index, method in
                    button(method, isPrimary: index == 0)
                }
            }
            .padding(.top, DSSpacing.xl + 2)

            Spacer(minLength: 0)

            Text(Strings.Auth.methodFootnote)
                .dsFont(DSFont.caption(DSType.captionSmall))
                .foregroundStyle(palette.textTertiary.color)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: .infinity)
                .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
    }

    private func button(_ method: LoginMethod, isPrimary: Bool) -> some View {
        Button { onPick(method) } label: {
            HStack(spacing: 9) {
                // 微信 / QQ / Apple 的图标必须使用各平台**官方品牌素材**，
                // 并遵守各自品牌规范。这里是占位，不可直接上线。
                Image(systemName: iconName(method))
                    .font(.system(size: 16, weight: .regular))
                Text(title(method)).dsFont(DSFont.body(DSType.bodyLarge))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md + 1)
            .foregroundStyle(isPrimary ? palette.background.color : palette.textPrimary.color)
            .background {
                if isPrimary {
                    RoundedRectangle(cornerRadius: DSRadius.field + 1).fill(palette.textPrimary.color)
                } else {
                    RoundedRectangle(cornerRadius: DSRadius.field + 1).dsHairline(palette.line)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func title(_ method: LoginMethod) -> String {
        switch method {
        case .wechat: return Strings.Auth.wechat
        case .qq:     return Strings.Auth.qq
        case .phone:  return Strings.Auth.phone
        case .apple:  return Strings.Auth.apple
        }
    }

    private func iconName(_ method: LoginMethod) -> String {
        switch method {
        case .wechat: return "message"
        case .qq:     return "bubble.left"
        case .phone:  return "number"
        case .apple:  return "apple.logo"
        }
    }
}

// MARK: - 手机号（ACCOUNT/02）

struct PhoneInputStep: View {
    let palette: Palette
    let onSubmit: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phone = ""
    /// **不得默认勾选**（5.14.3 法规硬性要求）。
    @State private var agreed = false
    @State private var shakeOffset: CGFloat = 0
    @State private var highlightAgreement = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Strings.Auth.phoneTitle)
                .dsFont(DSFont.title(DSType.question - 1))
                .foregroundStyle(palette.textPrimary.color)

            HStack(spacing: DSSpacing.cardGap) {
                Text(Strings.Auth.countryCode)
                    .dsFont(DSFont.title(19))
                    .foregroundStyle(palette.textSecondary.color)
                TextField(Strings.Auth.phonePlaceholder, text: $phone)
                    .dsFont(DSFont.title(22))
                    .foregroundStyle(palette.textPrimary.color)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .onChange(of: phone) { _, new in
                        phone = String(new.filter(\.isNumber).prefix(11))
                    }
            }
            .padding(.bottom, DSSpacing.md)
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.line.color).frame(height: DSStroke.hairline)
            }
            .padding(.top, DSSpacing.xl)

            agreementRow.padding(.top, DSSpacing.lg + 2)

            Spacer(minLength: 0)

            // 注意按钮**不因未勾选而置灰** —— 置灰的话用户不知道为什么点不动。
            DSPrimaryButtonLike(title: Strings.Auth.sendCode, palette: palette,
                                enabled: PhoneStepPolicy.canTapSendCode(phone: phone)) {
                submit()
            }
            .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
        .onAppear { focused = true }
    }

    private var agreementRow: some View {
        Button {
            agreed.toggle()
            if agreed { highlightAgreement = false }
        } label: {
            HStack(alignment: .top, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.checkbox)
                        .stroke(agreed ? palette.textPrimary.color : palette.textTertiary.color,
                                lineWidth: 1)
                        .frame(width: 17, height: 17)
                    if agreed {
                        RoundedRectangle(cornerRadius: DSRadius.checkbox)
                            .fill(palette.textPrimary.color)
                            .frame(width: 17, height: 17)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(palette.background.color)
                    }
                }
                .padding(.top, 1)

                (Text(Strings.Auth.agreementPrefix)
                 + Text(Strings.Auth.userAgreement).underline()
                 + Text(Strings.Auth.agreementAnd)
                 + Text(Strings.Auth.privacyPolicy).underline())
                    .dsFont(DSFont.caption(11.5))
                    .foregroundStyle(highlightAgreement ? palette.warning.color
                                                        : palette.textTertiary.color)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .offset(x: shakeOffset)
    }

    private func submit() {
        switch PhoneStepPolicy.outcome(phone: phone, agreedToTerms: agreed) {
        case .send:
            onSubmit(phone)
        case .shakeAgreement:
            // **抖动 + 文字变警示色，不弹 Alert。**
            // Alert 打断感强，抖动能明确指向问题所在。
            highlightAgreement = true
            guard !reduceMotion else { return }
            let amplitude = DSMotion.Shake.amplitude
            withAnimation(.linear(duration: DSMotion.Shake.duration.seconds / 4)) {
                shakeOffset = -amplitude
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + DSMotion.Shake.duration.seconds / 4) {
                withAnimation(.linear(duration: DSMotion.Shake.duration.seconds / 2)) {
                    shakeOffset = amplitude
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + DSMotion.Shake.duration.seconds / 2) {
                    withAnimation(.linear(duration: DSMotion.Shake.duration.seconds / 4)) {
                        shakeOffset = 0
                    }
                }
            }
        case .ignored:
            break
        }
    }
}

// MARK: - 验证码（ACCOUNT/03）

struct CodeInputStep: View {
    let phone: String
    let palette: Palette
    let errorText: String?
    let onComplete: (String) -> Void
    let onResend: () -> Void

    @State private var code = ""
    @State private var remaining = SMSRateLimit.perNumberCooldownSeconds
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Strings.Auth.codeTitle)
                .dsFont(DSFont.title(DSType.question - 1))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Auth.codeSentTo(PhoneMask.masked(phone)))
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.cardGapWide)

            cells.padding(.top, DSSpacing.xl)

            if let errorText {
                Text(errorText)
                    .dsFont(DSFont.caption(DSType.caption))
                    .foregroundStyle(palette.warning.color)
                    .padding(.top, DSSpacing.md)
            }

            resend.padding(.top, DSSpacing.lg + 4)

            Spacer(minLength: 0)

            Text(Strings.Auth.codeFootnote)
                .dsFont(DSFont.caption(DSType.captionSmall))
                .foregroundStyle(palette.textTertiary.color)
                .frame(maxWidth: .infinity)
                .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
        .background {
            // 隐藏的真实输入框。**不自动读取短信** —— 需权限，且这个人群对权限敏感。
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .focused($focused)
                .opacity(0)
                .onChange(of: code) { _, new in
                    code = String(new.filter(\.isNumber).prefix(VerificationCodePolicy.length))
                    // **输满 6 位自动提交**，不设「确认」按钮。
                    if VerificationCodePolicy.shouldAutoSubmit(code) { onComplete(code) }
                }
        }
        .onAppear { focused = true }
        .onChange(of: errorText) { _, new in
            // 验证码错误：清空并保持焦点，不跳转。
            if new != nil { code = ""; focused = true }
        }
        .task { await tick() }
    }

    private var cells: some View {
        HStack(spacing: 9) {
            ForEach(0..<VerificationCodePolicy.length, id: \.self) { index in
                let chars = Array(code)
                VStack {
                    Spacer()
                    Text(index < chars.count ? String(chars[index]) : "")
                        .dsFont(DSFont.title(26))
                        .foregroundStyle(palette.textPrimary.color)
                    Spacer()
                    Rectangle()
                        .fill(borderColor(index: index, filled: index < chars.count))
                        .frame(height: 1.5)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(0.78, contentMode: .fit)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    private func borderColor(index: Int, filled: Bool) -> Color {
        if errorText != nil { return palette.warning.color }
        if filled { return palette.textPrimary.color }
        if index == code.count { return palette.textSecondary.color }
        return palette.line.color
    }

    private var resend: some View {
        Group {
            if remaining > 0 {
                Text(Strings.Auth.resendIn(remaining))
                    .foregroundStyle(palette.textTertiary.color)
            } else {
                Button(Strings.Auth.resend) {
                    remaining = SMSRateLimit.perNumberCooldownSeconds
                    onResend()
                    Task { await tick() }
                }
                .foregroundStyle(palette.textSecondary.color)
            }
        }
        .dsFont(DSFont.caption(12.5))
        .frame(maxWidth: .infinity)
    }

    private func tick() async {
        while remaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            remaining -= 1
        }
    }
}

// MARK: - 年龄确认（ACCOUNT/04）

/// 《个人信息保护法》第 31 条：处理不满 14 周岁未成年人个人信息，须取得监护人同意。
///
/// # 隐私最小化
/// **只问是否年满 14 周岁，不问具体生日。**
/// 生日是可识别个人信息，而我们只需要一个布尔值。
struct AgeConfirmStep: View {
    let palette: Palette
    let onAnswer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Strings.Auth.ageTitle)
                .dsFont(DSFont.title(DSType.question - 1))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Auth.ageSubtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .lineSpacing(4)
                .padding(.top, DSSpacing.cardGapWide)

            // **两个选项等权呈现，不做视觉诱导。**
            VStack(spacing: DSSpacing.cardGapWide) {
                DSPrimaryButtonLike(title: Strings.Auth.ageOver14, palette: palette,
                                    enabled: true) { onAnswer(true) }
                Button { onAnswer(false) } label: {
                    Text(Strings.Auth.ageUnder14)
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textPrimary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md + 2)
                        .background {
                            RoundedRectangle(cornerRadius: DSRadius.button).dsHairline(palette.line)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, DSSpacing.xl + 2)

            Spacer(minLength: 0)

            Text(Strings.Auth.ageFootnote)
                .dsFont(DSFont.caption(DSType.captionSmall))
                .foregroundStyle(palette.textTertiary.color)
                .frame(maxWidth: .infinity)
                .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
    }
}

// MARK: - 监护人同意（ACCOUNT/05）

/// # 核心原则
/// **给出「先不绑定继续用」的出口，并放在同等显著位置。**
/// 未满 14 岁的用户不该被卡在这里 —— 他们仍是完整用户，本地数据不受任何影响。
struct GuardianConsentStep: View {
    let palette: Palette
    let onGuardianPresent: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 「需要家长帮个忙」而不是「您不符合注册条件」。
            Text(Strings.Auth.guardianTitle)
                .dsFont(DSFont.title(DSType.question - 1))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Auth.guardianSubtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.cardGapWide)

            Text(Strings.Auth.guardianTip)
                .dsFont(DSFont.caption(DSType.caption))
                .foregroundStyle(palette.textSecondary.color)
                .lineSpacing(5)
                .padding(DSSpacing.md + 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DSRadius.field))
                .padding(.top, DSSpacing.lg)

            VStack(spacing: DSSpacing.cardGapWide) {
                DSPrimaryButtonLike(title: Strings.Auth.guardianPresent, palette: palette,
                                    enabled: true, action: onGuardianPresent)
                Button(action: onSkip) {
                    Text(Strings.Auth.guardianSkip)
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textPrimary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md + 2)
                        .background {
                            RoundedRectangle(cornerRadius: DSRadius.button).dsHairline(palette.line)
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, DSSpacing.lg + 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
    }
}

// MARK: - 绑定成功（ACCOUNT/06）

/// 「存好了」而不是「登录成功」。
/// 列出**具体同步了什么** —— 具体的数字让用户确认价值，抽象的「同步完成」没有分量。
/// **不做庆祝动效** —— 这不是成就，是一次保险。
struct BindSuccessStep: View {
    let account: AuthAccount
    let stats: AuthFlowView.BindingStats
    let palette: Palette
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Circle()
                .stroke(palette.tree.color, lineWidth: 1)
                .frame(width: 62, height: 62)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(palette.tree.color)
                }

            Text(Strings.Auth.successTitle)
                .dsFont(DSFont.title(21))
                .foregroundStyle(palette.textPrimary.color)
                .padding(.top, DSSpacing.lg + 4)

            Text(Strings.Auth.successDetail(days: stats.days, notes: stats.notes,
                                            sealedLetters: stats.sealedLetters))
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, DSSpacing.md)

            Spacer()

            DSPrimaryButtonLike(title: Strings.Auth.successBack, palette: palette,
                                enabled: true, action: onBack)
                .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
    }
}
