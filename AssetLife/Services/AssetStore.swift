// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import Foundation
import SwiftData

/// 资产存储协议。UI 与 ViewModel 只依赖协议，便于测试与替换实现。
@MainActor
protocol AssetStoreProtocol {
    /// 按类型读取资产；`kind` 为 nil 时读取全部。
    func fetchAssets(kind: AssetKind?) throws -> [Asset]
    func asset(id: UUID) throws -> Asset?
    @discardableResult func addAsset(_ asset: Asset) throws -> Asset
    /// 更新已跟踪对象（SwiftData 自动跟踪；内存实现直接保存）。
    func update(_ asset: Asset) throws
    func delete(_ asset: Asset) throws
    func deleteAll() throws
    func deleteDemoData() throws
    func hasDemoData() throws -> Bool
    /// 写入演示数据；已有演示数据时不会重复写入。
    @discardableResult func insertDemoData(referenceDate: Date) throws -> Int
}

/// 基于 SwiftData 的存储实现。
@MainActor
struct SwiftDataAssetStore: AssetStoreProtocol {
    private let context: ModelContext
    /// 由本 store 创建的容器需在此持有：ModelContext 不保留 ModelContainer，
    /// 容器一旦释放，context 的底层存储栈失效，insert/fetch 会触发 SIGTRAP 崩溃。
    private let ownedContainer: ModelContainer?

    /// 供 SwiftUI 环境中的 modelContext 使用（容器由 SwiftUI 托管，生命周期有保障）。
    init(context: ModelContext) {
        self.context = context
        self.ownedContainer = nil
    }

    /// 自行创建容器的场景（单元测试、脚本）：store 负责持有容器，保证上下文始终有效。
    init(container: ModelContainer) {
        self.ownedContainer = container
        self.context = container.mainContext
    }

    func fetchAssets(kind: AssetKind?) throws -> [Asset] {
        let all = try context.fetch(FetchDescriptor<Asset>(sortBy: [SortDescriptor(\Asset.purchaseDate, order: .reverse)]))
        guard let kind else { return all }
        return all.filter { $0.kind == kind }
    }

    func asset(id: UUID) throws -> Asset? {
        let predicate = #Predicate<Asset> { asset in
            asset.id == id
        }
        var descriptor = FetchDescriptor<Asset>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @discardableResult
    func addAsset(_ asset: Asset) throws -> Asset {
        context.insert(asset)
        try context.save()
        return asset
    }

    func update(_ asset: Asset) throws {
        asset.updatedAt = Date()
        try context.save()
    }

    func delete(_ asset: Asset) throws {
        context.delete(asset)
        try context.save()
    }

    func deleteAll() throws {
        let all = try context.fetch(FetchDescriptor<Asset>())
        for asset in all {
            context.delete(asset)
        }
        try context.save()
    }

    func deleteDemoData() throws {
        let demo = try context.fetch(FetchDescriptor<Asset>()).filter { $0.isDemoData }
        for asset in demo {
            context.delete(asset)
        }
        try context.save()
    }

    func hasDemoData() throws -> Bool {
        try context.fetch(FetchDescriptor<Asset>()).contains { $0.isDemoData }
    }

    @discardableResult
    func insertDemoData(referenceDate: Date) throws -> Int {
        if try hasDemoData() { return 0 }
        let assets = DemoDataFactory.makeAssets(referenceDate: referenceDate)
        for asset in assets {
            context.insert(asset)
        }
        try context.save()
        return assets.count
    }
}

/// 内存存储实现：供单元测试与 SwiftUI Preview 使用，行为与线上实现一致。
@MainActor
final class InMemoryAssetStore: AssetStoreProtocol {
    private var storage: [Asset] = []

    init(assets: [Asset] = []) {
        self.storage = assets
    }

    func fetchAssets(kind: AssetKind?) throws -> [Asset] {
        guard let kind else {
            return storage.sorted { $0.purchaseDate > $1.purchaseDate }
        }
        return storage.filter { $0.kind == kind }.sorted { $0.purchaseDate > $1.purchaseDate }
    }

    func asset(id: UUID) throws -> Asset? {
        storage.first { $0.id == id }
    }

    @discardableResult
    func addAsset(_ asset: Asset) throws -> Asset {
        storage.append(asset)
        return asset
    }

    func update(_ asset: Asset) throws {
        asset.updatedAt = Date()
    }

    func delete(_ asset: Asset) throws {
        storage.removeAll { $0.id == asset.id }
    }

    func deleteAll() throws {
        storage.removeAll()
    }

    func deleteDemoData() throws {
        storage.removeAll { $0.isDemoData }
    }

    func hasDemoData() throws -> Bool {
        storage.contains { $0.isDemoData }
    }

    @discardableResult
    func insertDemoData(referenceDate: Date) throws -> Int {
        if try hasDemoData() { return 0 }
        let assets = DemoDataFactory.makeAssets(referenceDate: referenceDate)
        storage.append(contentsOf: assets)
        return assets.count
    }
}

/// 演示数据工厂：明确标记 `isDemoData`，可在设置中一键清除。
/// 仅在用户主动点击“载入演示数据”时写入，首次启动为空状态。
enum DemoDataFactory {
    static func makeAssets(referenceDate: Date, calendar: Calendar = .current) -> [Asset] {
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        }

        var assets: [Asset] = []

        assets.append(Asset(
            name: "MacBook Air M4",
            price: Decimal(9499),
            purchaseDate: daysAgo(426),
            category: "数码",
            status: .inUse,
            costMode: .perDay,
            iconName: "laptopcomputer",
            notes: "主力办公本，日均约 22 元。",
            tags: ["苹果", "办公"],
            isDemoData: true
        ))
        assets.append(Asset(
            name: "人体工学椅",
            price: Decimal(2180),
            purchaseDate: daysAgo(365),
            category: "家具",
            status: .inUse,
            costMode: .perDay,
            iconName: "bed.double.fill",
            tags: ["久坐必备"],
            isDemoData: true
        ))
        assets.append(Asset(
            name: "机械键盘 Keychron K8",
            price: Decimal(598),
            purchaseDate: daysAgo(233),
            category: "数码",
            status: .inUse,
            costMode: .perUse,
            useCount: 512,
            iconName: "keyboard",
            notes: "按次计算：约 1.17 元/次。",
            tags: ["外设"],
            isDemoData: true
        ))
        assets.append(Asset(
            name: "公路自行车",
            price: Decimal(4399),
            purchaseDate: daysAgo(198),
            category: "交通",
            status: .inUse,
            costMode: .perDay,
            iconName: "bicycle",
            notes: "通勤 + 周末骑行。",
            tags: ["运动", "通勤"],
            isDemoData: true
        ))
        assets.append(Asset(
            name: "咖啡机",
            price: Decimal(1299),
            purchaseDate: daysAgo(96),
            category: "厨具",
            status: .inUse,
            costMode: .perDay,
            iconName: "cup.and.saucer.fill",
            tags: ["早晨仪式"],
            isDemoData: true
        ))
        assets.append(Asset(
            name: "降噪耳机",
            price: Decimal(1899),
            purchaseDate: daysAgo(540),
            category: "数码",
            status: .retired,
            costMode: .perDay,
            iconName: "headphones",
            notes: "已更换新耳机，旧机退役。",
            isDemoData: true
        ))
        assets.append(Asset(
            name: "旧显示器",
            price: Decimal(1599),
            purchaseDate: daysAgo(700),
            category: "数码",
            status: .sold,
            costMode: .perDay,
            iconName: "display",
            notes: "已卖出，购入成本仍计入历史总额。",
            isDemoData: true
        ))

        let wishes: [(String, Decimal, Int, String, String)] = [
            ("相机 Sony A7C2", Decimal(15800), 62, "数码", "camera.fill"),
            ("露营帐篷", Decimal(2380), 35, "运动", "tent.fill"),
            ("电子书阅读器", Decimal(1099), 128, "数码", "book.fill"),
        ]
        for (name, price, days, category, icon) in wishes {
            assets.append(Asset(
                name: name,
                price: price,
                purchaseDate: daysAgo(-days),
                category: category,
                status: .inUse,
                kind: .wishlist,
                costMode: .perDay,
                iconName: icon,
                notes: "计划购入，尚未购买。",
                tags: ["心愿"],
                isDemoData: true
            ))
        }
        return assets
    }
}
