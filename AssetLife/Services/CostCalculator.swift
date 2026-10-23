import Foundation

/// 成本计算服务：纯函数，与 UI 完全解耦，便于单元测试。
///
/// 口径说明：
/// - 持有天数按自然日计算（`startOfDay` 后求差），购买当天记为第 1 天；
/// - 日期计算使用调用方传入的 `Calendar`，默认当前日历；
/// - 金额一律使用 `Decimal`，展示层再统一格式化为两位小数。
enum CostCalculator {

    /// 持有天数：自然日差值 + 1，至少为 1。
    static func holdingDays(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: startDay, to: endDay)
        let diff = components.day ?? 0
        return max(1, diff + 1)
    }

    /// 日均成本 = 购入价格 ÷ 持有天数（至少 1 天）。价格为负视为无效输入。
    static func dailyCost(price: Decimal, holdingDays: Int) -> Decimal? {
        guard price >= 0, holdingDays >= 1 else { return nil }
        return price / Decimal(holdingDays)
    }

    /// 单次成本 = 购入价格 ÷ 使用次数（至少 1 次）。
    static func perUseCost(price: Decimal, useCount: Int) -> Decimal? {
        guard price >= 0, useCount >= 1 else { return nil }
        return price / Decimal(useCount)
    }

    /// 求和（Decimal 精确累加）。
    static func sum(_ values: [Decimal]) -> Decimal {
        values.reduce(Decimal.zero) { $0 + $1 }
    }

    /// 按指定小数位四舍五入（用于展示与测试比较）。
    static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var result = Decimal()
        var mutable = value
        NSDecimalRound(&result, &mutable, scale, .plain)
        return result
    }
}
