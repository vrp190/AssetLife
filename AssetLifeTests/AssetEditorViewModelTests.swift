import XCTest

/// 编辑表单校验与保存测试。
@MainActor
final class AssetEditorViewModelTests: XCTestCase {

    private var store: InMemoryAssetStore!
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

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
        store = InMemoryAssetStore()
    }

    private func makeVM(asset: Asset? = nil, kind: AssetKind = .asset) -> AssetEditorViewModel {
        AssetEditorViewModel(asset: asset, defaultKind: kind, store: store, calendar: calendar)
    }

    // MARK: - 校验

    func testValidationRejectsEmptyName() {
        let vm = makeVM()
        vm.name = "   "
        vm.priceText = "100"
        let result = vm.validate(referenceDate: today)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.messages.contains { $0.contains("名称") })
    }

    func testValidationRejectsNegativePrice() {
        let vm = makeVM()
        vm.name = "X"
        vm.priceText = "-10"
        let result = vm.validate(referenceDate: today)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.messages.contains { $0.contains("负数") })
    }

    func testValidationRejectsBadPriceText() {
        let vm = makeVM()
        vm.name = "X"
        vm.priceText = "abc"
        let result = vm.validate(referenceDate: today)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.messages.contains { $0.contains("价格格式") })
    }

    func testValidationRejectsFutureDateForAsset() {
        let vm = makeVM()
        vm.name = "X"
        vm.priceText = "100"
        vm.kind = .asset
        vm.purchaseDate = calendar.date(byAdding: .day, value: 1, to: today)!
        let result = vm.validate(referenceDate: today)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.messages.contains { $0.contains("不能晚于今天") })
    }

    func testValidationAllowsFutureDateForWishlist() {
        let vm = makeVM(kind: .wishlist)
        vm.name = "X"
        vm.priceText = "100"
        vm.kind = .wishlist
        vm.purchaseDate = calendar.date(byAdding: .day, value: 30, to: today)!
        let result = vm.validate(referenceDate: today)
        XCTAssertTrue(result.isValid)
    }

    func testValidationPerUseRequiresCount() {
        let vm = makeVM()
        vm.name = "X"
        vm.priceText = "100"
        vm.purchaseDate = today
        vm.costMode = .perUse
        vm.useCountText = ""
        XCTAssertFalse(vm.validate(referenceDate: today).isValid)

        vm.useCountText = "10"
        XCTAssertTrue(vm.validate(referenceDate: today).isValid)
    }

    func testValidationCustomModeRequiresValue() {
        let vm = makeVM()
        vm.name = "X"
        vm.priceText = "100"
        vm.purchaseDate = today
        vm.costMode = .custom
        vm.targetValueText = ""
        XCTAssertFalse(vm.validate(referenceDate: today).isValid)

        vm.targetValueText = "2.50"
        XCTAssertTrue(vm.validate(referenceDate: today).isValid)
    }

    func testValidationByDateTargetCannotPrecedePurchase() {
        let vm = makeVM()
        vm.name = "X"
        vm.priceText = "100"
        vm.purchaseDate = calendar.date(byAdding: .day, value: -10, to: today)!
        vm.targetMode = .byDate
        vm.targetDate = calendar.date(byAdding: .day, value: -20, to: today)!
        XCTAssertFalse(vm.validate(referenceDate: today).isValid)
    }

    // MARK: - 保存

    func testSaveCreatesAssetWithParsedValues() throws {
        let vm = makeVM()
        vm.name = " 机械键盘 "
        vm.priceText = "¥598.00"
        vm.purchaseDate = today
        vm.category = "数码"
        vm.tagsText = "外设, 苹果 ,"
        vm.notes = "备注"
        let asset = try vm.save(referenceDate: today)

        XCTAssertEqual(asset.name, "机械键盘")
        XCTAssertEqual(asset.price, Decimal(string: "598.00"))
        XCTAssertEqual(asset.tags, ["外设", "苹果"])
        XCTAssertEqual(asset.kind, .asset)
        XCTAssertEqual(try store.fetchAssets(kind: nil).count, 1)
    }

    func testSaveThrowsWhenInvalid() {
        let vm = makeVM()
        vm.name = ""
        vm.priceText = "100"
        XCTAssertThrowsError(try vm.save(referenceDate: today))
    }

    func testSaveUpdatesExistingAssetKeepsID() throws {
        let existing = Asset(
            name: "旧名字",
            price: Decimal(100),
            purchaseDate: calendar.date(byAdding: .day, value: -30, to: today)!,
            category: "数码",
            status: .inUse,
            kind: .asset
        )
        try store.addAsset(existing)

        let vm = makeVM(asset: existing)
        XCTAssertTrue(vm.isEditing)
        XCTAssertEqual(vm.navigationTitle, "编辑资产")

        vm.name = "新名字"
        vm.priceText = "250"
        vm.status = .retired
        let saved = try vm.save(referenceDate: today)

        XCTAssertEqual(saved.id, existing.id)
        XCTAssertEqual(saved.name, "新名字")
        XCTAssertEqual(saved.price, Decimal(250))
        XCTAssertEqual(saved.status, .retired)
        XCTAssertEqual(try store.fetchAssets(kind: nil).count, 1)
    }

    func testSaveWishlistCreatesWish() throws {
        let vm = makeVM(kind: .wishlist)
        vm.name = "相机"
        vm.priceText = "15800"
        vm.purchaseDate = calendar.date(byAdding: .day, value: 60, to: today)!
        let asset = try vm.save(referenceDate: today)

        XCTAssertEqual(asset.kind, .wishlist)
        XCTAssertEqual(try store.fetchAssets(kind: .wishlist).count, 1)
        XCTAssertEqual(try store.fetchAssets(kind: .asset).count, 0)
        // 心愿不计入资产总额
        let summary = AssetListViewModel().summary(try store.fetchAssets(kind: nil), referenceDate: today, calendar: calendar)
        XCTAssertEqual(summary.totalCount, 0)
        XCTAssertEqual(summary.totalPurchaseCost, .zero)
    }

    // MARK: - 未保存修改检测

    func testHasUnsavedChanges() throws {
        let existing = Asset(
            name: "A",
            price: Decimal(100),
            purchaseDate: today,
            category: "数码",
            status: .inUse,
            kind: .asset
        )
        try store.addAsset(existing)
        let vm = makeVM(asset: existing)
        XCTAssertFalse(vm.hasUnsavedChanges)
        vm.name = "B"
        XCTAssertTrue(vm.hasUnsavedChanges)
    }
}
