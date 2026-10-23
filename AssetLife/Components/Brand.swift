import SwiftUI

/// 品牌视觉规范（规格 §5.1）。
enum Brand {
    /// 强调绿 #9BE52E：用于进度条、按钮底色、徽章底色（配深色文字）。
    static let accent = Color(red: 0x9B / 255, green: 0xE5 / 255, blue: 0x2E / 255)
    /// 强调绿深色变体：用于文字与图标，保证浅色背景上的对比度。
    static let accentDeep = Color(red: 0x4E / 255, green: 0x7D / 255, blue: 0x12 / 255)

    /// 页面背景 #F5F5F7
    static let background = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    /// 主文字 #171717
    static let primaryText = Color(red: 0x17 / 255, green: 0x17 / 255, blue: 0x17 / 255)
    /// 次级文字 #8A8A8A
    static let secondaryText = Color(red: 0x8A / 255, green: 0x8A / 255, blue: 0x8A / 255)
    /// 错误/删除：柔和红
    static let destructive = Color(red: 0xC7 / 255, green: 0x4A / 255, blue: 0x4A / 255)
    /// 卡片描边
    static let cardStroke = Color(red: 0xEC / 255, green: 0xEC / 255, blue: 0xF0 / 255)

    /// 卡片圆角 24–30pt
    static let cardRadius: CGFloat = 26
    /// 主按钮圆角（胶囊）
    static let buttonRadius: CGFloat = 999

    /// 状态语义色（状态同时以文字与图标表达，颜色只是辅助）。
    static func statusColor(_ status: AssetStatus) -> Color {
        switch status {
        case .inUse: return accent
        case .retired: return Color(red: 0xE0 / 255, green: 0x9F / 255, blue: 0x3E / 255)
        case .sold: return Color(red: 0x5B / 255, green: 0x7C / 255, blue: 0x99 / 255)
        }
    }
}

/// 卡片容器：白底、圆角、柔和阴影。
struct CardContainer<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous)
                    .stroke(Brand.cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

/// 主按钮（胶囊、强调绿底、深色文字）。
struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Brand.primaryText)
            .background(Brand.accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// 状态徽章：图标 + 文字（不只依赖颜色）。
struct StatusPill: View {
    let status: AssetStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImage)
                .font(.system(size: 8))
            Text(status.title)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Brand.statusColor(status))
        .background(Brand.statusColor(status).opacity(0.14))
        .clipShape(Capsule())
    }
}

/// 通用圆形图标底座。
struct IconBadge: View {
    let systemImage: String
    var size: CGFloat = 44
    var tint: Color = Brand.accent

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}
