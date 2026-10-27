// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import XCTest

/// 成本计算与日期边界测试。
final class CostCalculatorTests: XCTestCase {

    private var utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = TimeZone(identifier: "UTC")!
        return utcCalendar.date(from: components)!
    }

    // MARK: - 持有天数

    func testHoldingDaysPurchaseTodayIsOne() {
        let today = date(2024, 3, 15, 9)
        XCTAssertEqual(CostCalculator.holdingDays(from: today, to: date(2024, 3, 15, 23), calendar: utcCalendar), 1)
    }

    func testHoldingDaysNextDayIsTwo() {
        XCTAssertEqual(CostCalculator.holdingDays(from: date(2024, 3, 15), to: date(2024, 3, 16), calendar: utcCalendar), 2)
    }

    func testHoldingDaysWithinSameMonth() {
        // 3月1日 -> 3月31日 = 31 天
        XCTAssertEqual(CostCalculator.holdingDays(from: date(2024, 3, 1), to: date(2024, 3, 31), calendar: utcCalendar), 31)
    }

    func testHoldingDaysAcrossMonthBoundary() {
        // 2月29日(闰年) -> 3月1日 = 2 天
        XCTAssertEqual(CostCalculator.holdingDays(from: date(2024, 2, 29), to: date(2024, 3, 1), calendar: utcCalendar), 2)
    }

    func testHoldingDaysAcrossYearBoundary() {
        // 2023-12-31 -> 2024-01-01 = 2 天
        XCTAssertEqual(CostCalculator.holdingDays(from: date(2023, 12, 31), to: date(2024, 1, 1), calendar: utcCalendar), 2)
    }

    func testHoldingDaysIgnoresTimeOfDay() {
        // 同一天的不同时刻仍是 1 天
        XCTAssertEqual(CostCalculator.holdingDays(from: date(2024, 3, 15, 0), to: date(2024, 3, 15, 23, ), calendar: utcCalendar), 1)
    }

    func testHoldingDaysAcrossDSTBoundary() {
        // 美国纽约时区 2024-03-10 夏令时开始：自然日差值不应受时区偏移影响
        var dstCalendar = Calendar(identifier: .gregorian)
        dstCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        var start = DateComponents()
        start.year = 2024; start.month = 3; start.day = 9; start.hour = 23
        start.timeZone = TimeZone(identifier: "America/New_York")!
        let startDate = dstCalendar.date(from: start)!
        var end = DateComponents()
        end.year = 2024; end.month = 3; end.day = 10; end.hour = 1
        end.timeZone = TimeZone(identifier: "America/New_York")!
        let endDate = dstCalendar.date(from: end)!
        XCTAssertEqual(CostCalculator.holdingDays(from: startDate, to: endDate, calendar: dstCalendar), 2)
    }

    func testHoldingDaysFutureDateClampsToOne() {
        // 未来日期（心愿）按 1 天处理，不产生负值
        XCTAssertEqual(CostCalculator.holdingDays(from: date(2024, 3, 15), to: date(2024, 3, 20), calendar: utcCalendar) >= 1, true)
        let future = CostCalculator.holdingDays(from: date(2024, 3, 20), to: date(2024, 3, 15), calendar: utcCalendar)
        XCTAssertEqual(future, 1)
    }

    // MARK: - 日均成本

    func testDailyCostBasic() {
        let cost = CostCalculator.dailyCost(price: Decimal(100), holdingDays: 4)
        XCTAssertNotNil(cost)
        XCTAssertEqual(CostCalculator.rounded(cost!, scale: 2), Decimal(string: "25.00"))
    }

    func testDailyCostRoundingTwoDecimals() {
        let cost = CostCalculator.dailyCost(price: Decimal(100), holdingDays: 3)!
        XCTAssertEqual(CostCalculator.rounded(cost, scale: 2), Decimal(string: "33.33"))
        XCTAssertEqual(NSDecimalNumber(decimal: cost).doubleValue, 33.3333333, accuracy: 0.0001)
    }

    func testDailyCostOneDayEqualsPrice() {
        let cost = CostCalculator.dailyCost(price: Decimal(string: "3221.98")!, holdingDays: 1)!
        XCTAssertEqual(cost, Decimal(string: "3221.98"))
    }

    func testDailyCostZeroDaysReturnsNil() {
        XCTAssertNil(CostCalculator.dailyCost(price: Decimal(100), holdingDays: 0))
    }

    func testDailyCostNegativePriceReturnsNil() {
        XCTAssertNil(CostCalculator.dailyCost(price: Decimal(-5), holdingDays: 3))
    }

    func testDailyCostDecimalPrecision() {
        // Decimal 精确计算：0.1 + 0.2 场景不出现浮点误差
        let cost = CostCalculator.dailyCost(price: Decimal(string: "0.30")!, holdingDays: 3)!
        XCTAssertEqual(cost, Decimal(string: "0.1"))
    }

    // MARK: - 按次成本

    func testPerUseCostBasic() {
        let cost = CostCalculator.perUseCost(price: Decimal(598), useCount: 512)!
        XCTAssertEqual(CostCalculator.rounded(cost, scale: 2), Decimal(string: "1.17"))
    }

    func testPerUseCostZeroCountReturnsNil() {
        XCTAssertNil(CostCalculator.perUseCost(price: Decimal(598), useCount: 0))
    }

    func testPerUseCostNegativePriceReturnsNil() {
        XCTAssertNil(CostCalculator.perUseCost(price: Decimal(-1), useCount: 3))
    }

    // MARK: - 求和

    func testSumExact() {
        let sum = CostCalculator.sum([Decimal(string: "0.1")!, Decimal(string: "0.2")!, Decimal(string: "3221.98")!])
        XCTAssertEqual(sum, Decimal(string: "3222.28")!)
    }

    func testSumEmptyIsZero() {
        XCTAssertEqual(CostCalculator.sum([]), Decimal.zero)
    }
}
