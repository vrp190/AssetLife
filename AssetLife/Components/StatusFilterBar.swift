import SwiftUI

/// 状态筛选条：全部 / 使用中 / 已退役 / 已卖出。
struct StatusFilterBar: View {
    @Binding var selection: AssetStatus?
    var counts: [AssetStatus?: Int]? = nil

    private var options: [AssetStatus?] {
        [nil] + AssetStatus.allCases.map { Optional($0) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    filterChip(option)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .accessibilityLabel("状态筛选")
    }

    private func filterChip(_ option: AssetStatus?) -> some View {
        let isSelected = selection == option
        let title = option?.title ?? "全部"
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = option
            }
        } label: {
            HStack(spacing: 5) {
                if let option {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 9))
                }
                Text(title)
                if let counts, let count = counts.first(where: { $0.key == option })?.value {
                    Text("\(count)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isSelected ? Brand.primaryText.opacity(0.7) : Brand.secondaryText)
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Brand.primaryText : Brand.secondaryText)
            .background(isSelected ? Brand.accent : Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Brand.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
