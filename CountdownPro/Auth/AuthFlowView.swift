import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens

/// 登录全流程（需求文档 5.14 / auth 原型 ACCOUNT/01–06）。
///
/// 登录方式 → 手机号 → 验证码 → 年龄确认 →（未满 14 则监护人）→ 存好了。
struct AuthFlowView: View {

    let stats: BindingStats
    let onFinished: (AuthAccount, Bool) -> Void

    struct BindingStats {
        let days: Int
        let notes: Int
        let sealedLetters: Int
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private enum Step: Equatable {
        case method
        case phone
        case code(phone: String)
        case age(pending: PendingBinding)
        case guardianConsent
        case success(AuthAccount)
    }

    private struct PendingBinding: Equatable {
        let method: LoginMethod
        let phone: String?
        let code: String?
    }

    @State private var step: Step = .method
    @State private var busy: String?
    @State private var errorText: String?

    private let service: AuthService = MockAuthService()
    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

    var body: some View {
        ZStack {
            palette.background.color.ignoresSafeArea()

            VStack(spacing: 0) {
                if showsNavBar { navBar }
                content
            }

            if let busy {
                ZStack {
                    Color.black.opacity(0.86).ignoresSafeArea()
                    VStack(spacing: DSSpacing.md) {
                        ProgressView().tint(palette.textPrimary.color)
                        Text(busy)
                            .dsFont(DSFont.caption(12.5))
                            .foregroundStyle(palette.textSecondary.color)
                    }
                }
            }
        }
    }

    private var showsNavBar: Bool {
        if case .success = step { return false }
        return true
    }

    private var navBar: some View {
        HStack {
            Button { back() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, DSSpacing.lg)
        .frame(height: 52)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .method:
            LoginMethodStep(palette: palette) { method in
                if method == .phone {
                    step = .phone
                } else {
                    startThirdParty(method)
                }
            }

        case .phone:
            PhoneInputStep(palette: palette) { phone in
                Task { await sendCode(to: phone) }
            }

        case .code(let phone):
            CodeInputStep(phone: phone, palette: palette, errorText: errorText) { code in
                Task { await verify(code: code, phone: phone) }
            } onResend: {
                Task { await sendCode(to: phone, isResend: true) }
            }

        case .age(let pending):
            AgeConfirmStep(palette: palette) { isOver14 in
                if isOver14 {
                    Task { await complete(pending: pending, isOver14: true) }
                } else {
                    step = .guardianConsent
                }
            }

        case .guardianConsent:
            GuardianConsentStep(palette: palette) {
                // 监护人确认流程 V1 走 H5，尚未接入。
            } onSkip: {
                // **未满 14 岁的用户不该被卡在这里 —— 他们仍是完整用户。**
                // 本地数据不受任何影响。
                dismiss()
            }

        case .success(let account):
            BindSuccessStep(account: account, stats: stats, palette: palette) {
                dismiss()
            }
        }
    }

    // MARK: - 动作

    private func back() {
        switch step {
        case .method:           dismiss()
        case .phone:            step = .method
        case .code:             step = .phone
        case .age:              step = .method
        case .guardianConsent:  step = .method
        case .success:          break
        }
    }

    private func startThirdParty(_ method: LoginMethod) {
        busy = method == .apple
            ? Strings.Auth.verifying
            : Strings.Auth.redirecting(platformName(method))
        Task {
            // 年龄确认放在**验证成功之后、绑定完成之前**。
            defer { busy = nil }
            try? await Task.sleep(for: .milliseconds(600))
            step = .age(pending: PendingBinding(method: method, phone: nil, code: nil))
        }
    }

    private func platformName(_ method: LoginMethod) -> String {
        switch method {
        case .wechat: return "微信"
        case .qq:     return "QQ"
        default:      return ""
        }
    }

    private func sendCode(to phone: String, isResend: Bool = false) async {
        do {
            try await service.sendCode(to: phone)
            errorText = nil
            // 短信到达前的等待**不显示 loading** —— 用户会去看短信。
            if !isResend { step = .code(phone: phone) }
        } catch {
            errorText = Strings.Auth.codeWrong
        }
    }

    private func verify(code: String, phone: String) async {
        do {
            _ = try await service.verifyCode(code, phone: phone, isOver14: true)
            errorText = nil
            step = .age(pending: PendingBinding(method: .phone, phone: phone, code: code))
        } catch AuthError.lockedOut {
            errorText = Strings.Auth.codeLocked
        } catch {
            // 验证码错误：保持在本屏，不跳转。
            errorText = Strings.Auth.codeWrong
        }
    }

    private func complete(pending: PendingBinding, isOver14: Bool) async {
        do {
            let account: AuthAccount
            if pending.method == .phone, let phone = pending.phone, let code = pending.code {
                account = try await service.verifyCode(code, phone: phone, isOver14: isOver14)
            } else {
                account = try await service.signIn(with: pending.method, isOver14: isOver14)
            }
            onFinished(account, isOver14)
            step = .success(account)
        } catch {
            // 同步/绑定失败不得阻塞任何功能 —— 直接退出，本地数据完好。
            dismiss()
        }
    }
}
