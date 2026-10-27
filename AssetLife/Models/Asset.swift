// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import Foundation
import SwiftData

/// 资产状态。状态在 UI 中必须同时展示文字与颜色，不能只靠颜色区分。
enum AssetStatus: String, Codable, CaseIterable, Identifiable {
    case inUse
    case retired
    case sold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inUse: return "使用中"
        case .retired: return "已退役"
        case .sold: return "已卖出"
        }
    }

    var systemImage: String {
        switch self {
        case .inUse: return "circle.fill"
        case .retired: return "moon.fill"
        case .sold: return "tag.fill"
        }
    }
}

/// 条目类型：正式资产或心愿。
enum AssetKind: String, Codable, CaseIterable, Identifiable {
    case asset
    case wishlist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .asset: return "资产"
        case .wishlist: return "心愿"
        }
    }
}

/// 成本计算规则。
enum CostMode: String, Codable, CaseIterable, Identifiable {
    case perDay
    case perUse
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .perDay: return "按天计算"
        case .perUse: return "按次计算"
        case .custom: return "自定义金额"
        }
    }

    var detail: String {
        switch self {
        case .perDay: return "日均成本 = 购入价格 ÷ 持有天数（当天按 1 天）"
        case .perUse: return "单次成本 = 购入价格 ÷ 使用次数"
        case .custom: return "直接使用你设定的每日成本金额"
        }
    }
}

/// 目标日均成本的设定方式。
enum TargetDailyCostMode: String, Codable, CaseIterable, Identifiable {
    case none
    case byDate
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "不设置"
        case .byDate: return "按目标日期"
        case .custom: return "自定义金额"
        }
    }
}

/// 资产业务模型（SwiftData 持久化）。
///
/// 金额使用 `Decimal` 存储与计算，避免浮点误差；
/// 不存储任何格式化后的字符串。
@Model
final class Asset {
    var id: UUID
    var name: String
    var price: Decimal
    var purchaseDate: Date
    var category: String
    var status: AssetStatus
    var kind: AssetKind
    var costMode: CostMode
    var useCount: Int
    var iconName: String
    var notes: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    // 目标日均成本
    var targetModeRaw: String
    var targetValue: Decimal?
    var targetDate: Date?

    // 演示数据标记，便于一键清除
    var isDemoData: Bool

    init(
        id: UUID = UUID(),
        name: String,
        price: Decimal,
        purchaseDate: Date,
        category: String,
        status: AssetStatus = .inUse,
        kind: AssetKind = .asset,
        costMode: CostMode = .perDay,
        useCount: Int = 0,
        iconName: String = "cube.box.fill",
        notes: String = "",
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        targetMode: TargetDailyCostMode = .none,
        targetValue: Decimal? = nil,
        targetDate: Date? = nil,
        isDemoData: Bool = false
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.purchaseDate = purchaseDate
        self.category = category
        self.status = status
        self.kind = kind
        self.costMode = costMode
        self.useCount = useCount
        self.iconName = iconName
        self.notes = notes
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetModeRaw = targetMode.rawValue
        self.targetValue = targetValue
        self.targetDate = targetDate
        self.isDemoData = isDemoData
    }

    // MARK: - 派生访问器

    var targetMode: TargetDailyCostMode {
        get { TargetDailyCostMode(rawValue: targetModeRaw) ?? .none }
        set { targetModeRaw = newValue.rawValue }
    }

    /// 持有天数（自然日），购买当天按 1 天计；未来日期按 1 天处理，避免负值。
    func holdingDays(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        CostCalculator.holdingDays(from: purchaseDate, to: referenceDate, calendar: calendar)
    }

    /// 按天模式的日均成本。
    func dailyCost(referenceDate: Date = Date(), calendar: Calendar = .current) -> Decimal? {
        CostCalculator.dailyCost(price: price, holdingDays: holdingDays(referenceDate: referenceDate, calendar: calendar))
    }

    /// 按次模式的单次成本；使用次数不足 1 时返回 nil（无法计算）。
    func perUseCost() -> Decimal? {
        CostCalculator.perUseCost(price: price, useCount: useCount)
    }

    /// 当前成本模式下有效的“每日成本”数值；不可计算时返回 nil。
    func effectiveDailyCost(referenceDate: Date = Date(), calendar: Calendar = .current) -> Decimal? {
        switch costMode {
        case .perDay: return dailyCost(referenceDate: referenceDate, calendar: calendar)
        case .perUse: return perUseCost()
        case .custom: return targetValue
        }
    }

    /// 目标日均成本（按目标日期推导时由购入价格与目标日期计算）。
    func resolvedTargetDailyCost() -> Decimal? {
        switch targetMode {
        case .none: return nil
        case .custom: return targetValue
        case .byDate:
            guard let targetDate else { return nil }
            let days = CostCalculator.holdingDays(from: purchaseDate, to: targetDate)
            return CostCalculator.dailyCost(price: price, holdingDays: days)
        }
    }

    func matches(searchText: String) -> Bool {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if needle.isEmpty { return true }
        if name.lowercased().contains(needle) { return true }
        if category.lowercased().contains(needle) { return true }
        return tags.contains { $0.lowercased().contains(needle) }
    }
}

extension Asset: Identifiable {}
