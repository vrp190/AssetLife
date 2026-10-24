import XCTest
import Foundation

/// 单件资产/day 趋势序列的测试。
///
/// 关键点：这些用例直接对应线上反馈——购买日期在当月的物品，趋势图此前只有 1 个点，
/// 折线与面积都画不出来（Mac 显示空白 / iOS 隐藏卡片）。
final class CostTrendTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var trendCalendar: Calendar { calendar }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func asset(
        purchaseDate: Date,
        price: Decimal = 1200,
        costMode: CostMode = .perDay
    ) -> Asset {
        Asset(
            name: "测试物品",
            price: price,
            purchaseDate: purchaseDate,
            category: "数码",
            costMode: costMode
        )
    }

    // MARK: - 粒度切换

    func testShortHoldingUsesDailyGranularity() {
        XCTAssertEqual(AssetCostTrend.granularity(holdingDays: 1), .daily)
        XCTAssertEqual(AssetCostTrend.granularity(holdingDays: 5), .daily)
        XCTAssertEqual(AssetCostTrend.granularity(holdingDays: AssetCostTrend.dailyWindowDays), .daily)
    }

    func testLongHoldingUsesMonthlyGranularity() {
        XCTAssertEqual(
            AssetCostTrend.granularity(holdingDays: AssetCostTrend.dailyWindowDays + 1),
            .monthly
        )
        XCTAssertEqual(AssetCostTrend.granularity(holdingDays: 800), .monthly)
    }

    // MARK: - 按天序列（核心回归用例）

    func testSameMonthPurchaseProducesMultiplePoints() {
        // 购买日期与参考日期在同一个月：旧实现只会产出 1 个月度点，导致图表空白。
        let purchase = date(2024, 6, 12)
        let reference = date(2024, 6, 15)
        let series = AssetCostTrend.series(
            for: asset(purchaseDate: purchase),
            referenceDate: reference,
            calendar: trendCalendar
        )

        XCTAssertEqual(series.count, 4, "6/12 ~ 6/15 应产出 4 个日采样点")
        XCTAssertEqual(series.first?.dailyCost, 1200, "首日日均成本等于购入价")
        XCTAssertEqual(series.last?.dailyCost, 300, "第 4 天日均成本应为 1200 / 4")
    }

    func testPurchasedTodayStillProducesSinglePoint() {
        let reference = date(2024, 6, 15)
        let series = AssetCostTrend.series(
            for: asset(purchaseDate: reference),
            referenceDate: reference,
            calendar: trendCalendar
        )

        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series.first?.dailyCost, 1200)
    }

    func testDailySeriesDailyCostDecreasesMonotonically() {
        let purchase = date(2024, 6, 1)
        let reference = date(2024, 6, 10)
        let series = AssetCostTrend.series(
            for: asset(purchaseDate: purchase),
            referenceDate: reference,
            calendar: trendCalendar
        )

        XCTAssertEqual(series.count, 10)
        let costs = series.map { NSDecimalNumber(decimal: $0.dailyCost).doubleValue }
        for index in 1..<costs.count {
            XCTAssertLessThan(costs[index], costs[index - 1], "日均成本应随持有天数单调下降")
        }
    }

    func testDatesInDailySeriesAreAscending() {
        let purchase = date(2024, 6, 1)
        let series = AssetCostTrend.series(
            for: asset(purchaseDate: purchase),
            referenceDate: date(2024, 6, 8),
            calendar: trendCalendar
        )
        let days = series.map { calendar.component(.day, from: $0.date) }
        XCTAssertEqual(days, [1, 2, 3, 4, 5, 6, 7, 8])
    }

    // MARK: - 按月序列

    func testLongHoldingProducesMonthlyPoints() {
        let purchase = date(2023, 1, 15)
        let reference = date(2024, 1, 10)
        let series = AssetCostTrend.series(
            for: asset(purchaseDate: purchase),
            referenceDate: reference,
            calendar: trendCalendar
        )

        XCTAssertGreaterThanOrEqual(series.count, 12, "跨越 13 个月应至少有 12 个月度点")
        XCTAssertGreaterThan(series.first?.dailyCost ?? .zero, series.last?.dailyCost ?? .zero)
        let days = Set(series.map { calendar.component(.day, from: $0.date) })
        XCTAssertEqual(days, [1], "月度采样点应对齐到当月第一天")
    }

    // MARK: - 边界与非按天模式

    func testNonPerDayModeHasNoSeries() {
        let series = AssetCostTrend.series(
            for: asset(purchaseDate: date(2024, 6, 1), costMode: .perUse),
            referenceDate: date(2024, 6, 10),
            calendar: trendCalendar
        )
        XCTAssertTrue(series.isEmpty, "按次模式没有日均成本趋势")
    }

    func testZeroPriceHasNoSeries() {
        let series = AssetCostTrend.series(
            for: asset(purchaseDate: date(2024, 6, 1), price: 0),
            referenceDate: date(2024, 6, 10),
            calendar: trendCalendar
        )
        XCTAssertTrue(series.isEmpty)
    }

    func testFuturePurchaseDateIsClampedToOneDay() {
        let series = AssetCostTrend.series(
            for: asset(purchaseDate: date(2024, 6, 20)),
            referenceDate: date(2024, 6, 15),
            calendar: trendCalendar
        )
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series.first?.dailyCost, 1200, "未来日期按 1 天处理，日均成本等于购入价")
    }
}
