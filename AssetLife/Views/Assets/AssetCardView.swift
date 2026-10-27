// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import SwiftUI

/// 双列网格中的资产卡片：图标、状态、名称、购入价、持有天数、日均成本。
struct AssetCardView: View {
    let asset: Asset

    private var days: Int {
        asset.holdingDays()
    }

    private var dailyCost: Decimal? {
        asset.effectiveDailyCost()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconBadge(systemImage: asset.iconName, size: 38, tint: Brand.statusColor(asset.status))
                Spacer()
                StatusPill(status: asset.status)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(MoneyFormatter.string(asset.price))
                    .font(.caption)
                    .foregroundStyle(Brand.secondaryText)
            }

            Divider()
                .overlay(Brand.cardStroke)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(MoneyFormatter.string(dailyCost))
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(Brand.accentDeep)
                    Text("/天")
                        .font(.caption2)
                        .foregroundStyle(Brand.secondaryText)
                }
                Text("持有 \(days) 天")
                    .font(.caption2)
                    .foregroundStyle(Brand.secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous)
                .stroke(Brand.cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
