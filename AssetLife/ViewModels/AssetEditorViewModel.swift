// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import Foundation
import SwiftData

/// 编辑/新增表单的校验结果。
struct AssetEditorValidation: Equatable {
    var isValid: Bool
    var messages: [String]

    static let valid = AssetEditorValidation(isValid: true, messages: [])
}

/// 新增/编辑资产 ViewModel：表单状态、校验与保存。
@MainActor
final class AssetEditorViewModel: ObservableObject {

    // MARK: - 表单状态

    @Published var name: String = ""
    @Published var priceText: String = ""
    @Published var purchaseDate: Date = Date()
    @Published var category: String = AssetCategory.electronics.rawValue
    @Published var status: AssetStatus = .inUse
    @Published var kind: AssetKind = .asset
    @Published var costMode: CostMode = .perDay
    @Published var useCountText: String = ""
    @Published var iconName: String = "cube.box.fill"
    @Published var notes: String = ""
    @Published var tagsText: String = ""
    @Published var targetMode: TargetDailyCostMode = .none
    @Published var targetValueText: String = ""
    @Published var targetDate: Date = Date()
    @Published var isDemoData: Bool = false

    @Published var validation: AssetEditorValidation = .valid

    private let existingAsset: Asset?
    private let store: AssetStoreProtocol
    private let calendar: Calendar
    private var initialSnapshot: Snapshot = .empty

    /// 表单初始快照，用于检测未保存修改。
    private struct Snapshot: Equatable {
        var name: String = ""
        var priceText: String = ""
        var purchaseDate: Date = Date()
        var category: String = ""
        var status: AssetStatus = .inUse
        var kind: AssetKind = .asset
        var costMode: CostMode = .perDay
        var useCountText: String = ""
        var iconName: String = ""
        var notes: String = ""
        var tagsText: String = ""
        var targetMode: TargetDailyCostMode = .none
        var targetValueText: String = ""
        var targetDate: Date = Date()

        static let empty = Snapshot()
    }

    var isEditing: Bool { existingAsset != nil }

    /// 表单是否被修改过（用于取消时提示）。
    var hasUnsavedChanges: Bool {
        currentSnapshot != initialSnapshot
    }

    private var currentSnapshot: Snapshot {
        Snapshot(
            name: name,
            priceText: priceText,
            purchaseDate: purchaseDate,
            category: category,
            status: status,
            kind: kind,
            costMode: costMode,
            useCountText: useCountText,
            iconName: iconName,
            notes: notes,
            tagsText: tagsText,
            targetMode: targetMode,
            targetValueText: targetValueText,
            targetDate: targetDate
        )
    }

    var navigationTitle: String {
        if existingAsset != nil {
            return kind == .wishlist ? "编辑心愿" : "编辑资产"
        }
        return kind == .wishlist ? "新增心愿" : "新增资产"
    }

    init(asset: Asset? = nil, defaultKind: AssetKind = .asset, store: AssetStoreProtocol, calendar: Calendar = .current) {
        self.existingAsset = asset
        self.store = store
        self.calendar = calendar
        if let asset {
            self.name = asset.name
            self.priceText = MoneyFormatter.plain(asset.price)
            self.purchaseDate = asset.purchaseDate
            self.category = asset.category
            self.status = asset.status
            self.kind = asset.kind
            self.costMode = asset.costMode
            self.useCountText = asset.useCount > 0 ? String(asset.useCount) : ""
            self.iconName = asset.iconName
            self.notes = asset.notes
            self.tagsText = asset.tags.joined(separator: ", ")
            self.targetMode = asset.targetMode
            self.targetValueText = asset.targetValue.map { MoneyFormatter.plain($0) } ?? ""
            self.targetDate = asset.targetDate ?? asset.purchaseDate
            self.isDemoData = asset.isDemoData
        } else {
            self.kind = defaultKind
        }
        self.initialSnapshot = currentSnapshot
    }

    // MARK: - 校验

    func validate(referenceDate: Date = Date()) -> AssetEditorValidation {
        var messages: [String] = []

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            messages.append("名称不能为空")
        } else if trimmedName.count > 40 {
            messages.append("名称不能超过 40 个字符")
        }

        let trimmedPrice = priceText.trimmingCharacters(in: .whitespaces)
        if trimmedPrice.isEmpty {
            messages.append("价格不能为空")
        } else if let price = MoneyFormatter.parse(trimmedPrice) {
            if price < 0 {
                messages.append("价格不能为负数")
            }
        } else {
            messages.append("价格格式不正确")
        }

        // 未来日期仅心愿可用；资产必须是今天或更早
        if kind == .asset,
           calendar.startOfDay(for: purchaseDate) > calendar.startOfDay(for: referenceDate) {
            messages.append("资产的购买日期不能晚于今天（未来计划请选择“心愿”类型）")
        }

        if costMode == .perUse {
            if let count = Int(useCountText.trimmingCharacters(in: .whitespaces)), count >= 1 {
                // ok
            } else {
                messages.append("按次计算需要填写使用次数（至少 1 次）")
            }
        }

        if costMode == .custom {
            if let value = MoneyFormatter.parse(targetValueText), value >= 0, !targetValueText.trimmingCharacters(in: .whitespaces).isEmpty {
                // ok
            } else {
                messages.append("自定义模式需要填写有效的每日成本金额")
            }
        }

        if targetMode == .byDate {
            if calendar.startOfDay(for: targetDate) < calendar.startOfDay(for: purchaseDate) {
                messages.append("目标日期不能早于购买日期")
            }
        }

        validation = AssetEditorValidation(isValid: messages.isEmpty, messages: messages)
        return validation
    }

    // MARK: - 保存

    @discardableResult
    func save(referenceDate: Date = Date()) throws -> Asset {
        let result = validate(referenceDate: referenceDate)
        guard result.isValid else {
            throw AssetEditorError.validationFailed(result.messages.joined(separator: "；"))
        }

        let price = MoneyFormatter.parse(priceText) ?? .zero
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var targetValue: Decimal? = nil
        if targetMode == .custom {
            targetValue = MoneyFormatter.parse(targetValueText)
        }
        let targetDateValue: Date? = targetMode == .byDate ? targetDate : nil
        let useCount = costMode == .perUse ? (Int(useCountText.trimmingCharacters(in: .whitespaces)) ?? 0) : 0

        if let existingAsset {
            existingAsset.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existingAsset.price = price
            existingAsset.purchaseDate = purchaseDate
            existingAsset.category = category
            existingAsset.status = status
            existingAsset.kind = kind
            existingAsset.costMode = costMode
            existingAsset.useCount = useCount
            existingAsset.iconName = iconName
            existingAsset.notes = notes
            existingAsset.tags = tags
            existingAsset.targetMode = targetMode
            existingAsset.targetValue = targetValue
            existingAsset.targetDate = targetDateValue
            try store.update(existingAsset)
            return existingAsset
        } else {
            let asset = Asset(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                price: price,
                purchaseDate: purchaseDate,
                category: category,
                status: status,
                kind: kind,
                costMode: costMode,
                useCount: useCount,
                iconName: iconName,
                notes: notes,
                tags: tags,
                createdAt: Date(),
                updatedAt: Date(),
                targetMode: targetMode,
                targetValue: targetValue,
                targetDate: targetDateValue,
                isDemoData: isDemoData
            )
            return try store.addAsset(asset)
        }
    }
}

enum AssetEditorError: Error, Equatable, LocalizedError {
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .validationFailed(let message): return message
        }
    }
}
