import SwiftUI
import CountdownKit
import DesignTokens

/// 心里话输入（需求文档 5.3 第 3–4 步）。
///
/// 打卡完成后立刻弹出，**完全选填**。
/// 「跳过」和「保存」等权呈现 —— 这一步不是打卡的必要条件，
/// 它的存在是为了让愿意写的人有地方写，不是为了提高"内容渗透率"。
struct NoteSheetView: View {

    let palette: Palette
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Strings.NoteSheet.title)
                .dsFont(DSFont.title(DSType.bodyLarge))
                .foregroundStyle(palette.textPrimary.color)

            Text(Strings.NoteSheet.subtitle)
                .dsFont(DSFont.caption(DSType.caption))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, 5)

            editor.padding(.top, DSSpacing.md + 2)

            HStack(spacing: DSSpacing.cardGap) {
                Button {
                    dismiss()
                } label: {
                    Text(Strings.NoteSheet.skip)
                        .dsFont(DSFont.body(DSType.body))
                        .foregroundStyle(palette.textSecondary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md - 1)
                        .background {
                            RoundedRectangle(cornerRadius: DSRadius.field).dsHairline(palette.line)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    onSave(text)
                    dismiss()
                } label: {
                    Text(Strings.NoteSheet.save)
                        .dsFont(DSFont.body(DSType.body))
                        .foregroundStyle(palette.background.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md - 1)
                        .background(palette.textPrimary.color,
                                    in: RoundedRectangle(cornerRadius: DSRadius.field))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, DSSpacing.md + 1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.lg + 2)
        .background(palette.surface.color)
        .onAppear { focused = true }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // 用户自己写的内容用**衬线**（设计系统 1.2）。
            // 产品说话用无衬线，用户说话用衬线 —— 这个区分让用户的文字显得郑重。
            TextEditor(text: $text)
                .dsFont(DSFont.userWritten(DSType.userNote))
                .foregroundStyle(palette.textPrimary.color)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .onChange(of: text) { _, newValue in
                    if newValue.count > Strings.NoteSheet.maxLength {
                        text = String(newValue.prefix(Strings.NoteSheet.maxLength))
                    }
                }

            if text.isEmpty {
                Text(Strings.NoteSheet.placeholder)
                    .dsFont(DSFont.userWritten(DSType.userNote))
                    .foregroundStyle(palette.textTertiary.color)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(DSSpacing.md - 2)
        .frame(height: 112)
        .background(palette.background.color, in: RoundedRectangle(cornerRadius: DSRadius.field))
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.field).dsHairline(palette.line)
        }
    }
}
