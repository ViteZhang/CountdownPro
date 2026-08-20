import Foundation
import Photos
import UIKit
import CountdownKit

/// 保存到相册。
///
/// # 权限最小化
/// 需求文档第 6 章：不申请通讯录 / 位置 / **相册读取**权限，
/// 仅需相册**写入**用于保存卡片 —— 所以这里用 `.addOnly`，
/// 它在系统弹窗上显示为「添加到照片」，不是「访问所有照片」。
///
/// 权限只在用户**点了「保存图片」之后**才请求。引导流程与首页都不碰它。
@MainActor
enum PhotoSaver {

    enum Result {
        case saved
        case denied
        case failed
    }

    static func save(_ image: UIImage) async -> Result {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .denied }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return .saved
        } catch {
            return .failed
        }
    }
}
