import SwiftUI

/// 圆形取景裁剪器:拖动移动图片、双指捏合(触控板)/按钮缩放,圆框定范围。
/// 导出 256px 圆形 PNG(几何与预览严格一致)。
struct IconCropView: View {
    let image: NSImage
    let onConfirm: (Data) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero
    @State private var pinchStartScale: CGFloat = 1

    private let boxSide: CGFloat = 180
    private let exportSide: CGFloat = 256

    // 初始 cover:照片铺满圆框(图标裁剪的标准初始态),拖动/缩放选取局部
    private var baseScale: CGFloat {
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(boxSide / image.size.width, boxSide / image.size.height)
    }
    private var displaySize: CGSize {
        CGSize(width: image.size.width * baseScale * scale,
               height: image.size.height * baseScale * scale)
    }
    /// 拖动边界:图片任一边不允许离开圆框
    private var offsetLimit: CGSize {
        CGSize(width: max(0, (displaySize.width - boxSide) / 2),
               height: max(0, (displaySize.height - boxSide) / 2))
    }

    private func clamped(_ o: CGSize) -> CGSize {
        CGSize(width: min(max(o.width, -offsetLimit.width), offsetLimit.width),
               height: min(max(o.height, -offsetLimit.height), offsetLimit.height))
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            canvas
            zoomControls
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.98))
    }

    private var header: some View {
        ZStack {
            Text("icon.crop.title")
                .font(.headline)
            HStack {
                Button("common.cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("icon.crop.use") {
                    if let data = exportPNG() { onConfirm(data) }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .font(.body.bold())
            }
        }
        .padding(.top, 10)
    }

    /// 圆外暗化(even-odd 挖洞,确定性几何)
    private struct HoleMask: Shape {
        let canvasSide: CGFloat
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.addRect(CGRect(origin: .zero, size: rect.size))
            path.addEllipse(in: CGRect(x: (rect.width - canvasSide) / 2 + 1.5,
                                       y: (rect.height - canvasSide) / 2 + 1.5,
                                       width: canvasSide - 3,
                                       height: canvasSide - 3))
            return path
        }
    }

    /// 取景画布:图片严格裁剪在 210 方框内 + 圆外暗化 + 圆环
    private var canvas: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: displaySize.width, height: displaySize.height)
                .offset(offset)
        }
        .frame(width: boxSide, height: boxSide)
        .clipped()
        .overlay(
            HoleMask(canvasSide: boxSide)
                .fill(.black.opacity(0.45))
        )
        .overlay(
            Circle()
                .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
        )
        .overlay(
            Circle()
                .strokeBorder(.black.opacity(0.25), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = clamped(CGSize(width: dragStartOffset.width + value.translation.width,
                                            height: dragStartOffset.height + value.translation.height))
                }
                .onEnded { _ in dragStartOffset = offset }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(max(pinchStartScale * value, 1), 8)
                    offset = clamped(offset)
                }
                .onEnded { _ in pinchStartScale = scale }
        )
    }

    /// 缩放控制:按钮(无触控板捏合也可用)
    private var zoomControls: some View {
        HStack(spacing: 16) {
            Button {
                scale = min(max(scale / 1.25, 1), 8)
                offset = clamped(offset)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(HoverIconButtonStyle())
            Text("\(Int(scale * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44)
            Button {
                scale = min(max(scale * 1.25, 1), 8)
                offset = clamped(offset)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(HoverIconButtonStyle())
        }
        .padding(.top, 2)
    }

    /// 导出:与预览完全一致的几何,256px 圆形
    private func exportPNG() -> Data? {
        let content = ZStack {
            Image(nsImage: image)
                .resizable()
                .frame(width: displaySize.width, height: displaySize.height)
                .offset(offset)
        }
        .frame(width: boxSide, height: boxSide)
        .clipShape(Circle())
        .padding((exportSide - boxSide) / 2)
        .frame(width: exportSide, height: exportSide)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
