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

    /// 文件选择(模态 runModal:begin 在 LSUIElement 应用实测不弹窗),PNG/JPG,≤5MB
    @MainActor
    static func pickFromPanel(onPick: @escaping (Data) -> Void) {
        // LSUIElement(accessory)下 NSOpenPanel 实测不显示(begin/runModal 均然,
        // adhoc 未签名环境)。标准修法:临时切 regular(保存面板的标准前提),
        // 结束后回 accessory;Dock 图标会闪现一下,可接受。
        StatusItemPanelController.shared.closePanel()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        defer { NSApp.setActivationPolicy(.accessory) }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = String(localized: "form.icon.pick.message")
        let response = panel.runModal()
        let handler = { (response: NSApplication.ModalResponse) in
            guard response == .OK, let url = panel.url else {
                if response != .OK { Self.log.info("用户取消选择") }
                return
            }
            // 反正选完即降采样到 256,上限只是防呆(相机原图常见 10-20MB,故 50MB)
            guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) else {
                Self.log.error("无法读取文件大小: \(url.lastPathComponent, privacy: .public)")
                return
            }
            guard size <= 50 * 1024 * 1024 else {
                Self.log.error("图片过大(\(size) bytes): \(url.lastPathComponent, privacy: .public)")
                return
            }
            Self.log.info("选中文件 \(size) bytes")
            if let data = pngData(from: url) {
                Self.log.info("图片解码成功 \(data.count) bytes: \(url.lastPathComponent, privacy: .public)")
                onPick(data)
            } else {
                Self.log.error("图片解码失败: \(url.lastPathComponent, privacy: .public)")
            }
        }
        handler(response)
    }
}
