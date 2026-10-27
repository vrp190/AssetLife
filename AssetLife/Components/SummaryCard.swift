// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import SwiftUI

/// 总览统计卡：在册数量、购入总成本、日均成本之和、状态进度条。
struct SummaryCard: View {
    let summary: AssetSummary
    var totalWishBudget: Decimal = .zero

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                // 顶部：在册数量
                HStack(alignment: .firstTextBaseline) {
                    Text("\(summary.inUseCount)/\(summary.totalCount)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.primaryText)
                        .contentTransition(.numericText())
                    Text("在册")
                        .font(.subheadline)
                        .foregroundStyle(Brand.secondaryText)
                    Spacer()
                    if totalWishBudget > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("心愿预算")
                                .font(.caption2)
                                .foregroundStyle(Brand.secondaryText)
                            Text(MoneyFormatter.string(totalWishBudget))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Brand.primaryText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                // 中部：两个核心指标
                HStack(spacing: 0) {
                    metric(
                        title: "购入总成本",
                        value: MoneyFormatter.string(summary.totalPurchaseCost),
                        caption: "全部正式资产"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .frame(height: 36)
                        .overlay(Brand.cardStroke)

                    metric(
                        title: "日均成本",
                        value: MoneyFormatter.string(summary.totalDailyCost),
                        caption: "使用中+已退役"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 状态进度条
                statusBar

                // 状态图例
                HStack(spacing: 14) {
                    legend(.inUse, count: summary.inUseCount)
                    legend(.retired, count: summary.retiredCount)
                    legend(.sold, count: summary.soldCount)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func metric(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Brand.secondaryText)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.primaryText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(Brand.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)，\(caption)")
    }

    private var statusBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(AssetStatus.allCases) { status in
                    let fraction = summary.statusFractions[status] ?? 0
                    if fraction > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Brand.statusColor(status))
                            .frame(width: max(4, geo.size.width * fraction - 2))
                            .accessibilityLabel("\(status.title) \(Int(fraction * 100))%")
                    }
                }
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.25), value: summary.statusFractions)
    }

    private func legend(_ status: AssetStatus, count: Int) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Brand.statusColor(status))
                .frame(width: 8, height: 8)
            Text("\(status.title) \(count)")
                .font(.caption2)
                .foregroundStyle(Brand.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title) \(count) 件")
    }
}
