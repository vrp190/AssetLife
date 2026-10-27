// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import Foundation
import SwiftData

/// 总览统计数据。`totalDailyCost` 的口径在 UI 中明示。
struct AssetSummary: Equatable {
    var totalCount: Int = 0
    var inUseCount: Int = 0
    var retiredCount: Int = 0
    var soldCount: Int = 0
    /// 全部正式资产的购入成本总和（含已卖出/已退役，不含心愿）。
    var totalPurchaseCost: Decimal = .zero
    /// 使用中 + 已退役资产的日均成本之和（不含已卖出、不含心愿）。
    var totalDailyCost: Decimal = .zero

    var statusFractions: [AssetStatus: Double] {
        guard totalCount > 0 else { return [:] }
        return [
            .inUse: Double(inUseCount) / Double(totalCount),
            .retired: Double(retiredCount) / Double(totalCount),
            .sold: Double(soldCount) / Double(totalCount),
        ]
    }
}

enum AssetSortOption: String, CaseIterable, Identifiable {
    case purchaseDateDesc
    case recentlyUpdated
    case nameAsc
    case priceDesc
    case dailyCostAsc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .purchaseDateDesc: return "购买日期（最新）"
        case .recentlyUpdated: return "最近更新"
        case .nameAsc: return "名称 A→Z"
        case .priceDesc: return "价格（最高）"
        case .dailyCostAsc: return "日均成本（最低）"
        }
    }
}

/// 资产列表 ViewModel：负责统计、筛选、搜索、排序等纯逻辑。
/// 不持有数据源，由视图通过 @Query 提供数据后调用。
struct AssetListViewModel {

    /// 计算总览统计（只统计 kind == .asset）。
    func summary(_ assets: [Asset], referenceDate: Date = Date(), calendar: Calendar = .current) -> AssetSummary {
        let realAssets = assets.filter { $0.kind == .asset }
        var summary = AssetSummary()
        summary.totalCount = realAssets.count
        summary.inUseCount = realAssets.filter { $0.status == .inUse }.count
        summary.retiredCount = realAssets.filter { $0.status == .retired }.count
        summary.soldCount = realAssets.filter { $0.status == .sold }.count
        summary.totalPurchaseCost = CostCalculator.sum(realAssets.map { $0.price })
        let held = realAssets.filter { $0.status == .inUse || $0.status == .retired }
        summary.totalDailyCost = CostCalculator.sum(
            held.compactMap { $0.effectiveDailyCost(referenceDate: referenceDate, calendar: calendar) }
        )
        return summary
    }

    /// 心愿预算统计。
    func wishlistSummary(_ assets: [Asset]) -> (count: Int, budget: Decimal) {
        let wishes = assets.filter { $0.kind == .wishlist }
        return (wishes.count, CostCalculator.sum(wishes.map { $0.price }))
    }

    /// 按状态筛选 + 搜索 + 排序后的可见资产。
    func visibleAssets(
        _ assets: [Asset],
        searchText: String,
        statusFilter: AssetStatus?,
        sortOption: AssetSortOption,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [Asset] {
        var result = assets
        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            result = result.filter { $0.matches(searchText: searchText) }
        }
        return sort(result, option: sortOption, referenceDate: referenceDate, calendar: calendar)
    }

    func sort(
        _ assets: [Asset],
        option: AssetSortOption,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [Asset] {
        switch option {
        case .purchaseDateDesc:
            return assets.sorted { $0.purchaseDate > $1.purchaseDate }
        case .recentlyUpdated:
            return assets.sorted { $0.updatedAt > $1.updatedAt }
        case .nameAsc:
            return assets.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .priceDesc:
            return assets.sorted { $0.price > $1.price }
        case .dailyCostAsc:
            return assets.sorted { lhs, rhs in
                let l = lhs.effectiveDailyCost(referenceDate: referenceDate, calendar: calendar) ?? Decimal.greatestFiniteMagnitude
                let r = rhs.effectiveDailyCost(referenceDate: referenceDate, calendar: calendar) ?? Decimal.greatestFiniteMagnitude
                if l == r { return lhs.name < rhs.name }
                return l < r
            }
        }
    }
}

/// 趋势页 ViewModel：月度序列、类别分布、状态分布。
struct TrendsViewModel {

    struct MonthlyPoint: Identifiable, Equatable {
        var id: Date { monthStart }
        let monthStart: Date
        /// 当月购入金额（仅正式资产）
        var monthlyPurchase: Decimal
        /// 截至当月末的累计购入成本
        var cumulativePurchase: Decimal
        /// 截至当月末，已购入资产的日均成本之和（按当月末计算持有天数）
        var dailyCostAsOf: Decimal
    }

    struct CategoryValue: Identifiable, Equatable {
        var id: String { category }
        let category: String
        let total: Decimal
        let count: Int
    }

    struct StatusValue: Identifiable, Equatable {
        var id: String { status.rawValue }
        let status: AssetStatus
        let count: Int
    }

    /// 生成最近 `months` 个月的序列（含当月）。
    func monthlyPoints(
        _ assets: [Asset],
        months: Int = 12,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [MonthlyPoint] {
        let realAssets = assets.filter { $0.kind == .asset }
        guard months > 0 else { return [] }

        var points: [MonthlyPoint] = []
        var cumulative: Decimal = .zero

        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: calendar.startOfMonth(referenceDate, calendar: calendar)) else { continue }
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
            let effectiveEnd = min(monthEnd, referenceDate)

            let monthly = CostCalculator.sum(
                realAssets.filter { calendar.isDate($0.purchaseDate, equalTo: monthStart, toGranularity: .month) }.map { $0.price }
            )
            cumulative += monthly

            let dailyCostAsOf = CostCalculator.sum(
                realAssets
                    .filter { $0.purchaseDate <= effectiveEnd }
                    .compactMap { $0.effectiveDailyCost(referenceDate: effectiveEnd, calendar: calendar) }
            )

            points.append(MonthlyPoint(
                monthStart: monthStart,
                monthlyPurchase: monthly,
                cumulativePurchase: cumulative,
                dailyCostAsOf: dailyCostAsOf
            ))
        }
        return points
    }

    func categoryBreakdown(_ assets: [Asset]) -> [CategoryValue] {
        let realAssets = assets.filter { $0.kind == .asset }
        let grouped = Dictionary(grouping: realAssets) { $0.category.isEmpty ? "未分类" : $0.category }
        return grouped.map { category, items in
            CategoryValue(category: category, total: CostCalculator.sum(items.map { $0.price }), count: items.count)
        }
        .sorted { $0.total > $1.total }
    }

    func statusBreakdown(_ assets: [Asset]) -> [StatusValue] {
        let realAssets = assets.filter { $0.kind == .asset }
        return AssetStatus.allCases.map { status in
            StatusValue(status: status, count: realAssets.filter { $0.status == status }.count)
        }
    }
}

extension Calendar {
    /// 日期所在月的第一天。
    func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
