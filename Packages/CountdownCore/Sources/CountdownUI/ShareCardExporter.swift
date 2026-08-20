import Foundation
import CountdownKit
import DesignTokens
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// 分享卡导出（需求文档 5.8.3）。
///
/// 3:4 竖版，导出 1080×1440，适配朋友圈与 QQ 空间。
///
/// # 为什么按 4× 渲染而不是直接画大图
/// 卡片在屏幕上和导出时必须是**同一个视图**，否则"所见"和"所得"会慢慢分叉。
/// 用 `ImageRenderer.scale` 放大，版式代码只有一份。
///
/// 验收标准要求导出图在微信、QQ 压缩后文字仍清晰可读 —— 1080 宽 + 4× 渲染
/// 是为此留的余量，正文字号在导出图上都在 40px 以上。
@MainActor
public enum ShareCardExporter {

    public static func render(content: ShareCardContent, palette: Palette) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(content: content, palette: palette))
        renderer.scale = ShareCardBuilder.exportScale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
#endif
