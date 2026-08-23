import SwiftUI
import UIKit
import CountdownKit
import CountdownUI
import DesignTokens

/// 一张卡的两个出口：**分享**（系统面板）与**保存到相册**。
///
/// # 为什么必须有"分享"这一条
/// 原来只有「保存图片」。想发朋友圈的人要走：保存 → 切到微信 → 打开相册 → 从几百张照片里
/// 翻出刚才那张 → 发。四步，而且第三步开始就已经离开这个 App 了，
/// 中途放弃的人不会有任何痕迹留下来。系统分享面板是一步，直接落到微信/QQ 的选人页。
///
/// 分享卡是零预算下唯一的获客渠道（D-11 不放二维码），
/// 在这里省下一个按钮，等于把整条链路的转化率压在最难的那一步上。
///
/// # 图只渲一次
/// 卡片一进来就渲染，两个按钮共用同一张图。
/// 原来的写法是点一次「保存」渲一次 —— 用户看到的和保存下来的是两次独立渲染的结果，
/// 只要中间有任何状态变化，"所见"和"所得"就分叉了。
///
/// # 失败必须看得见
/// 渲染失败时原来的代码 `guard ... else { return }` —— 点下去什么都不发生，
/// 用户只会以为自己没点到，然后再点一次。现在失败会说出来。
struct ShareCardActions: View {

    let content: ShareCardContent
    let palette: Palette
    /// 导出文件名里的日期。
    let dateText: String
    /// 前置的次要按钮（节点全屏卡的「不了」）。没有就不画。
    var leading: AnyView?
    let onToast: (String) -> Void
    /// 保存成功后调用。全屏递卡用它来关掉自己。
    var onSaved: () -> Void = {}

    @State private var image: UIImage?
    @State private var file: URL?
    @State private var renderFailed = false

    var body: some View {
        Group {
            if renderFailed {
                Text(Strings.ShareCard.renderFailed)
                    .dsFont(DSFont.caption(DSType.caption))
                    .foregroundStyle(palette.textSecondary.color)
                    .multilineTextAlignment(.center)
            } else {
                HStack(spacing: DSSpacing.cardGap) {
                    leading
                    shareButton
                    saveButton
                }
            }
        }
        // 依 kind 重置：分享卡面板上切一次页签，视图身份不变、@State 会留着，
        // 不清掉的话「心里话卡」上的分享按钮发出去的还是节点卡那张图。
        .task(id: content.kind) {
            image = nil
            file = nil
            renderFailed = false
            render()
        }
    }

    // MARK: - 两个出口

    @ViewBuilder
    private var shareButton: some View {
        // ShareLink 只有在图已经就绪时才出现 —— 一个点下去没反应的分享按钮
        // 比没有分享按钮更让人困惑。
        if let file {
            ShareLink(item: file, preview: SharePreview(Strings.ShareCard.sharePreviewTitle)) {
                label(Strings.ShareCard.share, filled: true)
            }
            .buttonStyle(.plain)
        } else {
            label(Strings.ShareCard.share, filled: true).opacity(DSOpacity.disabled)
        }
    }

    private var saveButton: some View {
        Button { save() } label: { label(Strings.ShareCard.saveImage, filled: false) }
            .buttonStyle(.plain)
            .disabled(image == nil)
    }

    private func label(_ title: String, filled: Bool) -> some View {
        Text(title)
            .dsFont(DSFont.body(DSType.body))
            .foregroundStyle(filled ? palette.background.color : palette.textPrimary.color)
            .padding(.horizontal, DSSpacing.lg + 2)
            .padding(.vertical, DSSpacing.md - 1)
            .background {
                if filled {
                    Capsule().fill(palette.textPrimary.color)
                } else {
                    Capsule().dsHairline(palette.line)
                }
            }
    }

    // MARK: - 渲染与保存

    private func render() {
        guard let made = ShareCardExporter.render(content: content, palette: palette) else {
            renderFailed = true
            return
        }
        image = made
        // 分享走临时文件而不是直接给 UIImage：文件名是我们能控制的，
        // 落到微信/QQ 里就是一个带产品名的文件，而不是 IMG_0042。
        file = ShareCardFile.write(made, named: Strings.ShareCard.fileName(dateText))
    }

    private func save() {
        guard let image else { return }
        Task {
            switch await PhotoSaver.save(image) {
            case .saved:
                onToast(Strings.ShareCard.savedToAlbum)
                onSaved()
            case .denied:
                onToast(Strings.ShareCard.saveDenied)
            case .failed:
                onToast(Strings.ShareCard.saveFailed)
            }
        }
    }
}

/// 分享用的临时文件。
///
/// 固定文件名、原子覆盖：不做清理也不会越堆越多，同一天导出多次就是同一个文件。
/// 放 `temporaryDirectory` 而不是 Documents —— 它不进 iCloud 备份，
/// 也不会出现在"文件"App 里让用户以为自己多了一堆垃圾。
enum ShareCardFile {
    static func write(_ image: UIImage, named name: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
