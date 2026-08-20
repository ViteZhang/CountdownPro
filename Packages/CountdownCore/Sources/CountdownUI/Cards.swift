import Foundation
import CountdownKit
import DesignTokens
#if canImport(SwiftUI)
import SwiftUI

/// 卡片容器。圆角 16、卡片色底（设计系统 1.3）。
public struct DSCard<Content: View>: View {
    private let palette: Palette
    private let content: () -> Content

    public init(palette: Palette, @ViewBuilder content: @escaping () -> Content) {
        self.palette = palette
        self.content = content
    }

    public var body: some View {
        content()
            .padding(.horizontal, DSSpacing.md + 2)
            .padding(.vertical, DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DSRadius.card))
    }
}

/// 主按钮。「今天也在」用的就是它。
public struct DSPrimaryButton: View {
    private let title: String
    private let palette: Palette
    private let isDone: Bool
    private let action: () -> Void

    public init(title: String, palette: Palette, isDone: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.palette = palette
        self.isDone = isDone
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title).dsFont(DSFont.body(15))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md + 1)
            .foregroundStyle(isDone ? palette.textSecondary.color : palette.background.color)
            .background {
                if isDone {
                    // 已完成态是描边而非实心 —— 它是一条记录，不是一个待办。
                    RoundedRectangle(cornerRadius: DSRadius.button)
                        .dsHairline(palette.line)
                } else {
                    RoundedRectangle(cornerRadius: DSRadius.button)
                        .fill(palette.textPrimary.color)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// 描边提示条。首页底部的信件提示用它。
public struct DSHintBar: View {
    private let text: String
    private let systemImage: String
    private let palette: Palette
    private let action: () -> Void

    public init(text: String, systemImage: String, palette: Palette, action: @escaping () -> Void) {
        self.text = text
        self.systemImage = systemImage
        self.palette = palette
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm + 1) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .light))
                Text(text).dsFont(DSFont.caption(12))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(palette.textSecondary.color)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.md - 2)
            .background {
                RoundedRectangle(cornerRadius: DSRadius.field).dsHairline(palette.line)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif
