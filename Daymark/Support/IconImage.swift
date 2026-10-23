import AppKit
import OSLog

/// 图标图片工具:导入时降采样到 256×256(列表 30pt/详情 44pt 足够,防大文件)
enum IconImage {
    private static let log = Logger(subsystem: "app.louvane.Daymark", category: "icon")
    static let maxPixelSize: CGFloat = 256

    /// 从磁盘图片生成降采样 PNG 数据;失败返回 nil
    static func pngData(from url: URL) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else { return nil }
        let downOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, downOptions as CFDictionary) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cg)
        return bitmap.representation(using: .png, properties: [:])
    }

    /// 文件选择(非模态 begin,适配非激活面板),PNG/JPG,≤5MB
    @MainActor
    static func pickFromPanel(onPick: @escaping (Data) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = String(localized: "form.icon.pick.message")
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize), size <= 5 * 1024 * 1024 else {
                if response == .OK { Self.log.error("图片过大或不可读") }
                return
            }
            if let data = pngData(from: url) {
                onPick(data)
            } else {
                Self.log.error("图片解码失败")
            }
        }
    }
}
