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

    private let boxSide: CGFloat = 210
    private let exportSide: CGFloat = 256

    // 图片基础铺满(cover)尺寸
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
                .frame(width: boxSide, height: boxSide)
            zoomControls
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
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

    /// 取景画布:图片 + 暗角蒙版 + 圆环
    private var canvas: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .frame(width: displaySize.width, height: displaySize.height)
                .offset(offset)
            // 圆外暗化
            Rectangle()
                .fill(.black.opacity(0.45))
                .reverseMask {
                    Circle()
                }
            Circle()
                .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
            Circle()
                .strokeBorder(.black.opacity(0.25), lineWidth: 0.5)
        }
        .clipped()
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

/// 反向蒙版:形状外填充
extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: .center) {
                    mask().blendMode(.destinationOut)
                }
                .compositingGroup()
        }
    }
}
