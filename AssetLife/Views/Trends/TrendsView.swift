// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import SwiftUI
import SwiftData
import Charts

/// 趋势页：月度购入金额、累计购入成本、日均成本趋势、类别分布、状态分布。
struct TrendsView: View {
    @Query(sort: \Asset.purchaseDate, order: .reverse) private var allAssets: [Asset]

    private let trends = TrendsViewModel()

    private var realAssets: [Asset] {
        allAssets.filter { $0.kind == .asset }
    }

    private var monthlyPoints: [TrendsViewModel.MonthlyPoint] {
        trends.monthlyPoints(allAssets)
    }

    private var hasData: Bool {
        !realAssets.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !hasData {
                    EmptyStateView(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "暂无趋势数据",
                        message: "添加资产后，这里会显示月度成本趋势与类别分布。"
                    )
                    .padding(.vertical, 60)
                } else {
                    monthlyChartCard
                    cumulativeChartCard
                    dailyCostChartCard
                    categoryCard
                    statusCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Brand.background.ignoresSafeArea())
        .navigationTitle("趋势")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - 图表卡片

    private var monthlyChartCard: some View {
        chartCard(
            title: "月度购入金额",
            caption: "当月购入正式资产的金额合计"
        ) {
            Chart(monthlyPoints) { point in
                BarMark(
                    x: .value("月份", DateFormatterBox.monthLabel.string(from: point.monthStart)),
                    y: .value("金额", NSDecimalNumber(decimal: point.monthlyPurchase).doubleValue)
                )
                .foregroundStyle(Brand.accent)
                .cornerRadius(4)
            }
        }
    }

    private var cumulativeChartCard: some View {
        chartCard(
            title: "累计购入成本",
            caption: "截至每月末的历史购入成本总和（含已卖出）"
        ) {
            Chart(monthlyPoints) { point in
                LineMark(
                    x: .value("月份", DateFormatterBox.monthLabel.string(from: point.monthStart)),
                    y: .value("累计", NSDecimalNumber(decimal: point.cumulativePurchase).doubleValue)
                )
                .foregroundStyle(Brand.accentDeep)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                AreaMark(
                    x: .value("月份", DateFormatterBox.monthLabel.string(from: point.monthStart)),
                    y: .value("累计", NSDecimalNumber(decimal: point.cumulativePurchase).doubleValue)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [Brand.accent.opacity(0.3), Brand.accent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private var dailyCostChartCard: some View {
        chartCard(
            title: "日均成本趋势",
            caption: "截至每月末，已购入资产的日均成本之和（按当月末推导）"
        ) {
            Chart(monthlyPoints) { point in
                LineMark(
                    x: .value("月份", DateFormatterBox.monthLabel.string(from: point.monthStart)),
                    y: .value("日均成本", NSDecimalNumber(decimal: point.dailyCostAsOf).doubleValue)
                )
                .foregroundStyle(Brand.accentDeep)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .symbol(Circle().strokeBorder(lineWidth: 2))
                .symbolSize(28)
            }
        }
    }

    private func chartCard<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(Brand.secondaryText)
                content()
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let double = value.as(Double.self) {
                                    Text(compactMoney(double))
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6))
                    }
                    .frame(height: 170)
            }
        }
    }

    private func compactMoney(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "%.1f万", value / 10000)
        }
        return String(format: "%.0f", value)
    }

    // MARK: - 类别分布

    private var categoryCard: some View {
        let breakdown = trends.categoryBreakdown(allAssets)
        let maxTotal = breakdown.map { $0.total }.max() ?? .zero
        return CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("类别成本分布")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)
                Text("按购入成本排序")
                    .font(.caption2)
                    .foregroundStyle(Brand.secondaryText)
                ForEach(breakdown.prefix(8)) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: AssetCategory.symbol(for: item.category))
                                .font(.caption)
                                .foregroundStyle(Brand.secondaryText)
                            Text(item.category)
                                .font(.subheadline)
                                .foregroundStyle(Brand.primaryText)
                            Spacer()
                            Text(MoneyFormatter.string(item.total))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Brand.primaryText)
                        }
                        GeometryReader { geo in
                            let fraction = maxTotal > 0 ? min(1.0, NSDecimalNumber(decimal: item.total / maxTotal).doubleValue) : 0
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Brand.accent)
                                .frame(width: max(4, geo.size.width * fraction))
                        }
                        .frame(height: 8)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.category) \(MoneyFormatter.string(item.total))")
                }
            }
        }
    }

    // MARK: - 状态分布

    private var statusCard: some View {
        let breakdown = trends.statusBreakdown(allAssets)
        return CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("状态分布")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)
                ForEach(breakdown) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.status.systemImage)
                            .font(.caption)
                            .foregroundStyle(Brand.statusColor(item.status))
                            .frame(width: 14)
                        Text(item.status.title)
                            .font(.subheadline)
                            .foregroundStyle(Brand.primaryText)
                        Spacer()
                        Text("\(item.count) 件")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Brand.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.status.title) \(item.count) 件")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TrendsView()
    }
    .modelContainer(for: Asset.self, inMemory: true)
}
