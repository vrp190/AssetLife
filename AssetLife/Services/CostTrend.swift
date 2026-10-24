import Foundation

/// 单件资产日均成本趋势的一个采样点。
struct CostTrendPoint: Hashable, Identifiable {
    /// 采样日：按天粒度为当天零点，按月粒度为当月第一天。
    let date: Date
    let dailyCost: Decimal

    var id: Date { date }
}

/// 趋势采样粒度。
enum CostTrendGranularity: Hashable {
    case daily
    case monthly
}

/// 单件资产的日均成本趋势。
///
/// 说明：App 不记录历史快照，趋势由购买日期推导（金额 ÷ 截至采样日的持有天数），
/// 因此短期持有按月采样只会得到 1 个点，画不出曲线。所以规则为：
/// - 持有天数 ≤ `dailyWindowDays`：按天采样，新物品也能立刻看到下降曲线；
/// - 超过窗口：按月采样，避免长时间跨度产生过多点。
enum AssetCostTrend {
    /// 按天采样的持有天数上限（约两个月）。
    static let dailyWindowDays = 62

    static func granularity(holdingDays: Int) -> CostTrendGranularity {
        holdingDays <= dailyWindowDays ? .daily : .monthly
    }

    static func series(
        for asset: Asset,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [CostTrendPoint] {
        guard asset.price > 0, asset.costMode == .perDay else { return [] }
        let days = CostCalculator.holdingDays(
            from: asset.purchaseDate,
            to: referenceDate,
            calendar: calendar
        )
        switch granularity(holdingDays: days) {
        case .daily:
            return dailySeries(for: asset, referenceDate: referenceDate, calendar: calendar)
        case .monthly:
            return monthlySeries(for: asset, referenceDate: referenceDate, calendar: calendar)
        }
    }

    // MARK: - 内部实现

    private static func dailySeries(
        for asset: Asset,
        referenceDate: Date,
        calendar: Calendar
    ) -> [CostTrendPoint] {
        let start = calendar.startOfDay(for: asset.purchaseDate)
        let end = calendar.startOfDay(for: referenceDate)
        var points: [CostTrendPoint] = []
        var day = start
        // +1 保证至少输出当前所在的那一天
        while day <= end, points.count <= dailyWindowDays {
            points.append(
                CostTrendPoint(
                    date: day,
                    dailyCost: cost(of: asset, asOf: endOfDay(day, calendar: calendar), calendar: calendar)
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        // 购买日期晚于参考日期（holdingDays 钳位为 1）时至少给一个点，避免图表空白
        if points.isEmpty {
            return [
                CostTrendPoint(
                    date: start,
                    dailyCost: cost(of: asset, asOf: referenceDate, calendar: calendar)
                )
            ]
        }
        return points
    }

    private static func monthlySeries(
        for asset: Asset,
        referenceDate: Date,
        calendar: Calendar
    ) -> [CostTrendPoint] {
        guard let monthComponents = Optional(calendar.dateComponents([.year, .month], from: asset.purchaseDate)),
              var month = calendar.date(from: monthComponents) else { return [] }
        var points: [CostTrendPoint] = []
        while month <= referenceDate, points.count < 240 {
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: month) ?? month
            let effectiveEnd = min(monthEnd, referenceDate)
            if effectiveEnd >= asset.purchaseDate {
                points.append(
                    CostTrendPoint(
                        date: month,
                        dailyCost: cost(of: asset, asOf: effectiveEnd, calendar: calendar)
                    )
                )
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return points
    }

    private static func cost(of asset: Asset, asOf date: Date, calendar: Calendar) -> Decimal {
        let days = CostCalculator.holdingDays(from: asset.purchaseDate, to: date, calendar: calendar)
        return CostCalculator.dailyCost(price: asset.price, holdingDays: days) ?? .zero
    }

    private static func endOfDay(_ day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 23, minute: 59, second: 59, of: day) ?? day
    }
}
