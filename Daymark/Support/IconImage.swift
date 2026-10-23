import AppKit
import OSLog
import UniformTypeIdentifiers

/// 图标图片工具:统一降采样到 256×256。
/// 文件选择:NSOpenPanel.runModal,不切 activation policy(切换会引发 XPC
/// 会话动荡、回调丢失),仅激活应用 + floating 层级保证窗口置前可见。
enum IconImage {

    /// 文件选择(PNG/JPG):返回 256px PNG 数据;取消返回 nil
    @MainActor
    static func pickImageFile() -> Data? {
        StatusItemPanelController.shared.closePanel()
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = String(localized: "form.icon.pick.message")
        panel.level = .floating
        let response = panel.runModal()
        log.info("runModal 返回 raw=\(response.rawValue) url=\(panel.url?.lastPathComponent ?? "nil", privacy: .public)")
        guard response == .OK, let url = panel.url else { return nil }
        guard let png = pngData(from: url) else {
            log.error("解码失败: \(url.lastPathComponent, privacy: .public)")
            return nil
        }
        log.info("文件导入成功 \(png.count) bytes")
        // 回到表单
        StatusItemPanelController.shared.showPanel()
        return png
    }

    private static let log = Logger(subsystem: "app.louvane.Daymark", category: "icon")
    static let maxPixelSize: CGFloat = 256

    /// 内存降采样:PNG/JPEG 原始数据 → 256px PNG
    static func pngData(fromImageData data: Data) -> Data? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else { return nil }
        return pngData(fromSource: source)
    }

    /// 文件 URL → 256px PNG
    static func pngData(from url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return pngData(fromSource: source)
    }

    private static func pngData(fromSource source: CGImageSource) -> Data? {
        let downOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, downOptions as CFDictionary) else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }

    /// 剪贴板 → 256px PNG(支持复制的图片/截图/文件)
    @MainActor
    static func pngDataFromPasteboard() -> Data? {
        let pb = NSPasteboard.general
        // 1) 直接的图片数据(png/tiff/jpeg)
        for type in [NSPasteboard.PasteboardType.png, .tiff, NSPasteboard.PasteboardType("public.jpeg")] {
            if let data = pb.data(forType: type), let png = pngData(fromImageData: data) {
                log.info("剪贴板图片数据导入(\(type.rawValue, privacy: .public))")
                return png
            }
        }
        // 2) TIFF 兜底(NSImage 通用形态)
        if let tiffData = (try? NSImage(pasteboard: pb))?.tiffRepresentation,
           let png = pngData(fromImageData: tiffData) {
            log.info("剪贴板 NSImage 导入")
            return png
        }
        // 3) 复制的文件(Finder ⌘C)
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           ["png", "jpg", "jpeg", "PNG", "JPG", "JPEG"].contains(url.pathExtension),
           let png = pngData(from: url) {
            log.info("剪贴板文件导入: \(url.lastPathComponent, privacy: .public)")
            return png
        }
        return nil
    }
}
