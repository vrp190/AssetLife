// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import XCTest

/// 总览统计、筛选、搜索、排序、趋势序列测试。
final class AssetListViewModelTests: XCTestCase {

    private var viewModel: AssetListViewModel!
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 固定“今天”，保证测试可重复。
    private var today: Date = {
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 15
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")!
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    override func setUp() {
        super.setUp()
        viewModel = AssetListViewModel()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }

    private func asset(
        name: String,
        price: Decimal,
        purchaseDate: Date,
        status: AssetStatus = .inUse,
        kind: AssetKind = .asset,
        category: String = "数码",
        tags: [String] = [],
        costMode: CostMode = .perDay,
        useCount: Int = 0
    ) -> Asset {
        Asset(
            name: name,
            price: price,
            purchaseDate: purchaseDate,
            category: category,
            status: status,
            kind: kind,
            costMode: costMode,
            useCount: useCount,
            iconName: "cube.box.fill",
            tags: tags
        )
    }

    // MARK: - 总览统计

    func testSummaryExcludesWishlist() {
        let assets = [
            asset(name: "A", price: Decimal(100), purchaseDate: date(2024, 6, 1)),
            asset(name: "B", price: Decimal(200), purchaseDate: date(2024, 5, 1)),
            asset(name: "W", price: Decimal(999), purchaseDate: date(2024, 7, 1), kind: .wishlist),
        ]
        let summary = viewModel.summary(assets, referenceDate: today, calendar: calendar)
        XCTAssertEqual(summary.totalCount, 2)
        XCTAssertEqual(summary.totalPurchaseCost, Decimal(300))
    }

    func testSummaryStatusCountsAndDailyCost() {
        let assets = [
            // 6月1日购入，6月15日 => 持有 15 天，日均 100/15
            asset(name: "A", price: Decimal(100), purchaseDate: date(2024, 6, 1), status: .inUse),
            // 6月5日购入 => 持有 11 天，日均 200/11
            asset(name: "B", price: Decimal(200), purchaseDate: date(2024, 6, 5), status: .inUse),
            // 已退役仍计入日均成本
            asset(name: "C", price: Decimal(50), purchaseDate: date(2024, 6, 10), status: .retired),
            // 已卖出不计入日均成本
            asset(name: "D", price: Decimal(30), purchaseDate: date(2024, 6, 12), status: .sold),
        ]
        let summary = viewModel.summary(assets, referenceDate: today, calendar: calendar)
        XCTAssertEqual(summary.totalCount, 4)
        XCTAssertEqual(summary.inUseCount, 2)
        XCTAssertEqual(summary.retiredCount, 1)
        XCTAssertEqual(summary.soldCount, 1)
        XCTAssertEqual(summary.totalPurchaseCost, Decimal(380))

        let expected = Decimal(100) / Decimal(15) + Decimal(200) / Decimal(11) + Decimal(50) / Decimal(6)
        XCTAssertEqual(summary.totalDailyCost, expected)
    }

    func testSummaryEmpty() {
        let summary = viewModel.summary([], referenceDate: today, calendar: calendar)
        XCTAssertEqual(summary.totalCount, 0)
        XCTAssertEqual(summary.totalPurchaseCost, .zero)
        XCTAssertEqual(summary.totalDailyCost, .zero)
        XCTAssertTrue(summary.statusFractions.isEmpty)
    }

    func testWishlistSummary() {
        let assets = [
            asset(name: "W1", price: Decimal(15800), purchaseDate: date(2024, 7, 1), kind: .wishlist),
            asset(name: "W2", price: Decimal(2380), purchaseDate: date(2024, 8, 1), kind: .wishlist),
            asset(name: "A", price: Decimal(500), purchaseDate: date(2024, 6, 1)),
        ]
        let result = viewModel.wishlistSummary(assets)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.budget, Decimal(18180))
    }

    // MARK: - 筛选 / 搜索 / 排序

    private func sampleAssets() -> [Asset] {
        [
            asset(name: "MacBook", price: Decimal(9499), purchaseDate: date(2024, 1, 1), status: .inUse, category: "数码", tags: ["苹果", "办公"]),
            asset(name: "椅子", price: Decimal(2180), purchaseDate: date(2024, 3, 1), status: .inUse, category: "家具", tags: ["久坐"]),
            asset(name: "键盘", price: Decimal(598), purchaseDate: date(2024, 5, 1), status: .inUse, category: "数码", tags: ["外设"], costMode: .perUse, useCount: 100),
            asset(name: "旧手机", price: Decimal(3000), purchaseDate: date(2023, 12, 1), status: .sold, category: "数码"),
            asset(name: "相机", price: Decimal(15800), purchaseDate: date(2024, 8, 1), kind: .wishlist),
        ]
    }

    func testFilterByStatus() {
        let result = viewModel.visibleAssets(
            sampleAssets(), searchText: "", statusFilter: .sold, sortOption: .purchaseDateDesc,
            referenceDate: today, calendar: calendar
        )
        XCTAssertEqual(result.map { $0.name }, ["旧手机"])
    }

    func testSearchByNameCategoryTag() {
        let assets = sampleAssets()
        XCTAssertEqual(viewModel.visibleAssets(assets, searchText: "键盘", statusFilter: nil, sortOption: .purchaseDateDesc, referenceDate: today, calendar: calendar).first?.name, "键盘")
        XCTAssertEqual(viewModel.visibleAssets(assets, searchText: "家具", statusFilter: nil, sortOption: .purchaseDateDesc, referenceDate: today, calendar: calendar).first?.name, "椅子")
        XCTAssertEqual(viewModel.visibleAssets(assets, searchText: "外设", statusFilter: nil, sortOption: .purchaseDateDesc, referenceDate: today, calendar: calendar).first?.name, "键盘")
        XCTAssertEqual(viewModel.visibleAssets(assets, searchText: "苹果", statusFilter: nil, sortOption: .purchaseDateDesc, referenceDate: today, calendar: calendar).first?.name, "MacBook")
        XCTAssertTrue(viewModel.visibleAssets(assets, searchText: "不存在的物品", statusFilter: nil, sortOption: .purchaseDateDesc, referenceDate: today, calendar: calendar).isEmpty)
    }

    private var assetOnlySample: [Asset] {
        sampleAssets().filter { $0.kind == .asset }
    }

    func testSortByPurchaseDateDesc() {
        let result = viewModel.visibleAssets(assetOnlySample, searchText: "", statusFilter: nil, sortOption: .purchaseDateDesc, referenceDate: today, calendar: calendar)
        // 键盘(5/1) > 椅子(3/1) > MacBook(1/1) > 旧手机(去年12/1)
        XCTAssertEqual(result.map { $0.name }, ["键盘", "椅子", "MacBook", "旧手机"])
    }

    func testSortByNameAsc() {
        // 使用纯 ASCII 名称，避免本地化中文排序规则差异
        let assets = [
            asset(name: "Zebra", price: Decimal(1), purchaseDate: date(2024, 1, 1)),
            asset(name: "apple", price: Decimal(2), purchaseDate: date(2024, 1, 2)),
            asset(name: "Mango", price: Decimal(3), purchaseDate: date(2024, 1, 3)),
        ]
        let result = viewModel.visibleAssets(assets, searchText: "", statusFilter: nil, sortOption: .nameAsc, referenceDate: today, calendar: calendar)
        XCTAssertEqual(result.map { $0.name }, ["apple", "Mango", "Zebra"])
    }

    func testSortByPriceDesc() {
        let result = viewModel.visibleAssets(assetOnlySample, searchText: "", statusFilter: nil, sortOption: .priceDesc, referenceDate: today, calendar: calendar)
        XCTAssertEqual(result.map { $0.name }, ["MacBook", "旧手机", "椅子", "键盘"])
    }

    func testSortByDailyCostAscPutsCheapestFirst() {
        // 键盘按次：598/100 = 5.98/次；MacBook 日均 9499/(1月1日->6月15日=166天) ≈ 57.2
        let result = viewModel.visibleAssets(sampleAssets(), searchText: "", statusFilter: nil, sortOption: .dailyCostAsc, referenceDate: today, calendar: calendar)
        XCTAssertEqual(result.first?.name, "键盘")
    }

    // MARK: - 趋势序列

    func testMonthlyPointsAggregation() {
        let assets = [
            asset(name: "A", price: Decimal(1000), purchaseDate: date(2024, 4, 10)),
            asset(name: "B", price: Decimal(500), purchaseDate: date(2024, 4, 20)),
            asset(name: "C", price: Decimal(2000), purchaseDate: date(2024, 5, 5)),
            asset(name: "W", price: Decimal(9999), purchaseDate: date(2024, 5, 6), kind: .wishlist),
        ]
        let points = TrendsViewModel().monthlyPoints(assets, months: 3, referenceDate: today, calendar: calendar)
        XCTAssertEqual(points.count, 3)

        // 四月
        let april = points[0]
        XCTAssertEqual(april.monthlyPurchase, Decimal(1500))
        XCTAssertEqual(april.cumulativePurchase, Decimal(1500))

        // 五月（心愿不计入）
        let may = points[1]
        XCTAssertEqual(may.monthlyPurchase, Decimal(2000))
        XCTAssertEqual(may.cumulativePurchase, Decimal(3500))

        // 六月（当月无购入，累计不变）
        let june = points[2]
        XCTAssertEqual(june.monthlyPurchase, .zero)
        XCTAssertEqual(june.cumulativePurchase, Decimal(3500))

        // 六月的日均成本之和包含 A/B/C（按 6月30日 之前的实际日末推导）
        XCTAssertTrue(june.dailyCostAsOf > 0)
    }

    func testCategoryBreakdownExcludesWishlist() {
        let assets = [
            asset(name: "A", price: Decimal(100), purchaseDate: date(2024, 1, 1), status: .inUse, category: "数码"),
            asset(name: "B", price: Decimal(300), purchaseDate: date(2024, 2, 1), status: .inUse, category: "数码"),
            asset(name: "C", price: Decimal(200), purchaseDate: date(2024, 2, 1), status: .inUse, category: "家具"),
            asset(name: "W", price: Decimal(999), purchaseDate: date(2024, 3, 1), kind: .wishlist),
        ]
        let breakdown = TrendsViewModel().categoryBreakdown(assets)
        XCTAssertEqual(breakdown.count, 2)
        XCTAssertEqual(breakdown.first?.category, "数码")
        XCTAssertEqual(breakdown.first?.total, Decimal(400))
        XCTAssertEqual(breakdown.first?.count, 2)
    }

    func testStatusBreakdown() {
        let assets = [
            asset(name: "A", price: Decimal(1), purchaseDate: date(2024, 1, 1), status: .inUse),
            asset(name: "B", price: Decimal(1), purchaseDate: date(2024, 1, 1), status: .retired),
            asset(name: "C", price: Decimal(1), purchaseDate: date(2024, 1, 1), status: .retired),
            asset(name: "D", price: Decimal(1), purchaseDate: date(2024, 1, 1), status: .sold),
        ]
        let breakdown = TrendsViewModel().statusBreakdown(assets)
        XCTAssertEqual(breakdown.first { $0.status == .inUse }?.count, 1)
        XCTAssertEqual(breakdown.first { $0.status == .retired }?.count, 2)
        XCTAssertEqual(breakdown.first { $0.status == .sold }?.count, 1)
    }
}
