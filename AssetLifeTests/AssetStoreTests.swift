import XCTest
import SwiftData

/// 存储层测试：内存实现 + SwiftData 内存容器。
@MainActor
final class AssetStoreTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func daysAgo(_ days: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -days, to: reference)!
    }

    private func makeAsset(name: String = "测试物品", price: Decimal = Decimal(100), kind: AssetKind = .asset) -> Asset {
        Asset(
            name: name,
            price: price,
            purchaseDate: daysAgo(10),
            category: "数码",
            status: .inUse,
            kind: kind,
            costMode: .perDay,
            iconName: "cube.box.fill"
        )
    }

    // MARK: - InMemoryAssetStore

    func testInMemoryAddAndFetch() throws {
        let store = InMemoryAssetStore()
        let asset = makeAsset()
        try store.addAsset(asset)

        let all = try store.fetchAssets(kind: nil)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(try store.fetchAssets(kind: .asset).count, 1)
        XCTAssertEqual(try store.fetchAssets(kind: .wishlist).count, 0)
        XCTAssertEqual(try store.asset(id: asset.id)?.name, "测试物品")
    }

    func testInMemoryDelete() throws {
        let store = InMemoryAssetStore()
        let asset = makeAsset()
        try store.addAsset(asset)
        try store.delete(asset)
        XCTAssertEqual(try store.fetchAssets(kind: nil).count, 0)
    }

    func testInMemoryDeleteAll() throws {
        let store = InMemoryAssetStore()
        try store.addAsset(makeAsset(name: "A"))
        try store.addAsset(makeAsset(name: "B"))
        try store.deleteAll()
        XCTAssertEqual(try store.fetchAssets(kind: nil).count, 0)
    }

    func testInMemoryDemoDataFlag() throws {
        let store = InMemoryAssetStore()
        let count = try store.insertDemoData(referenceDate: Date())
        XCTAssertEqual(count, 10)
        XCTAssertTrue(try store.hasDemoData())
        try store.deleteDemoData()
        XCTAssertFalse(try store.hasDemoData())
        XCTAssertEqual(try store.fetchAssets(kind: nil).count, 0)
    }

    func testInMemoryDemoDataNotDuplicated() throws {
        let store = InMemoryAssetStore()
        _ = try store.insertDemoData(referenceDate: Date())
        let second = try store.insertDemoData(referenceDate: Date())
        XCTAssertEqual(second, 0)
    }

    // MARK: - SwiftDataAssetStore（内存容器）

    private func makeSwiftDataStore() throws -> SwiftDataAssetStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Asset.self, configurations: config)
        // store 持有 container：ModelContext 不保留容器，局部容器被释放后
        // 继续 insert/fetch 会触发 SwiftData SIGTRAP 崩溃。
        return SwiftDataAssetStore(container: container)
    }

    func testSwiftDataAddFetchUpdateDelete() throws {
        let store = try makeSwiftDataStore()
        let asset = makeAsset()
        try store.addAsset(asset)

        let fetched = try store.fetchAssets(kind: .asset)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.price, Decimal(100))

        asset.name = "新名字"
        asset.price = Decimal(string: "199.99")!
        try store.update(asset)
        let updated = try store.asset(id: asset.id)
        XCTAssertEqual(updated?.name, "新名字")
        XCTAssertEqual(updated?.price, Decimal(string: "199.99"))

        try store.delete(asset)
        XCTAssertEqual(try store.fetchAssets(kind: .asset).count, 0)
    }

    func testSwiftDataPersistsEnumAndDecimalValues() throws {
        let store = try makeSwiftDataStore()
        let asset = Asset(
            name: "枚举测试",
            price: Decimal(string: "12.34")!,
            purchaseDate: daysAgo(5),
            category: "数码",
            status: .retired,
            kind: .asset,
            costMode: .perUse,
            useCount: 42,
            iconName: "keyboard",
            notes: "备注",
            tags: ["a", "b"]
        )
        try store.addAsset(asset)
        let fetched = try store.asset(id: asset.id)
        XCTAssertEqual(fetched?.status, .retired)
        XCTAssertEqual(fetched?.costMode, .perUse)
        XCTAssertEqual(fetched?.useCount, 42)
        XCTAssertEqual(fetched?.price, Decimal(string: "12.34"))
        XCTAssertEqual(fetched?.tags, ["a", "b"])
    }

    func testSwiftDataDeleteAllAndDemo() throws {
        let store = try makeSwiftDataStore()
        try store.addAsset(makeAsset(name: "A"))
        _ = try store.insertDemoData(referenceDate: Date())
        XCTAssertEqual(try store.fetchAssets(kind: nil).count, 11)
        try store.deleteDemoData()
        XCTAssertEqual(try store.fetchAssets(kind: nil).count, 1)
        try store.deleteAll()
        XCTAssertEqual(try store.fetchAssets(kind: nil).count, 0)
    }
}
