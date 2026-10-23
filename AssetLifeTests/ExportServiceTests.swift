import XCTest

/// 导出 / 导入校验测试。
final class ExportServiceTests: XCTestCase {

    private func sampleAssets() -> [Asset] {
        [
            Asset(
                name: "MacBook",
                price: Decimal(string: "9499.99")!,
                purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
                category: "数码",
                status: .inUse,
                kind: .asset,
                costMode: .perDay,
                iconName: "laptopcomputer",
                notes: "主力机",
                tags: ["苹果", "办公"]
            ),
            Asset(
                name: "相机",
                price: Decimal(15800),
                purchaseDate: Date(timeIntervalSince1970: 1_800_000_000),
                category: "数码",
                status: .inUse,
                kind: .wishlist,
                costMode: .perDay,
                iconName: "camera.fill",
                notes: "",
                tags: []
            ),
        ]
    }

    func testExportRoundTrip() throws {
        let assets = sampleAssets()
        let data = try ExportService.makePayload(assets: assets, exportedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let parsed = try ExportService.parsePayload(data)
        XCTAssertEqual(parsed.count, 2)

        let first = parsed.first { $0.name == "MacBook" }
        XCTAssertEqual(first?.price, Decimal(string: "9499.99"))
        XCTAssertEqual(first?.status, .inUse)
        XCTAssertEqual(first?.kind, .asset)
        XCTAssertEqual(first?.category, "数码")
        XCTAssertEqual(first?.tags, ["苹果", "办公"])
        XCTAssertEqual(first?.purchaseDate.timeIntervalSince1970.rounded(), 1_700_000_000)

        let wish = parsed.first { $0.kind == .wishlist }
        XCTAssertEqual(wish?.name, "相机")
    }

    func testExportPayloadIsReadableJSON() throws {
        let data = try ExportService.makePayload(assets: sampleAssets())
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["app"] as? String, "AssetLife")
        XCTAssertEqual(object?["formatVersion"] as? Int, 1)
        XCTAssertEqual((object?["assets"] as? [Any])?.count, 2)
    }

    func testImportRejectsInvalidJSON() {
        let data = Data("not json".utf8)
        XCTAssertThrowsError(try ExportService.parsePayload(data)) { error in
            XCTAssertEqual(error as? ExportError, .invalidJSON)
        }
    }

    func testImportRejectsUnsupportedVersion() throws {
        let payload = """
        {"app":"AssetLife","formatVersion":99,"exportedAt":"2024-01-01T00:00:00Z","assetCount":0,"assets":[]}
        """
        XCTAssertThrowsError(try ExportService.parsePayload(Data(payload.utf8))) { error in
            XCTAssertEqual(error as? ExportError, .unsupportedVersion(99))
        }
    }

    func testImportRejectsEmptyAssets() throws {
        let payload = """
        {"app":"AssetLife","formatVersion":1,"exportedAt":"2024-01-01T00:00:00Z","assetCount":0,"assets":[]}
        """
        XCTAssertThrowsError(try ExportService.parsePayload(Data(payload.utf8))) { error in
            XCTAssertEqual(error as? ExportError, .emptyPayload)
        }
    }

    func testImportRejectsMissingName() throws {
        let payload = """
        {"app":"AssetLife","formatVersion":1,"exportedAt":"2024-01-01T00:00:00Z","assetCount":1,"assets":[{"id":"\(UUID().uuidString)","name":"","price":"10","purchaseDate":"2024-01-01T00:00:00Z","category":"数码","status":"inUse","kind":"asset","costMode":"perDay","useCount":0,"iconName":"x","notes":"","tags":[],"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z","targetMode":"none","targetValue":null,"targetDate":null,"isDemoData":false}]}
        """
        XCTAssertThrowsError(try ExportService.parsePayload(Data(payload.utf8)))
    }

    func testImportRejectsNegativePrice() throws {
        let payload = """
        {"app":"AssetLife","formatVersion":1,"exportedAt":"2024-01-01T00:00:00Z","assetCount":1,"assets":[{"id":"\(UUID().uuidString)","name":"X","price":"-5","purchaseDate":"2024-01-01T00:00:00Z","category":"数码","status":"inUse","kind":"asset","costMode":"perDay","useCount":0,"iconName":"x","notes":"","tags":[],"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z","targetMode":"none","targetValue":null,"targetDate":null,"isDemoData":false}]}
        """
        XCTAssertThrowsError(try ExportService.parsePayload(Data(payload.utf8)))
    }

    func testImportRejectsBadStatus() throws {
        let payload = """
        {"app":"AssetLife","formatVersion":1,"exportedAt":"2024-01-01T00:00:00Z","assetCount":1,"assets":[{"id":"\(UUID().uuidString)","name":"X","price":"10","purchaseDate":"2024-01-01T00:00:00Z","category":"数码","status":"unknown","kind":"asset","costMode":"perDay","useCount":0,"iconName":"x","notes":"","tags":[],"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z","targetMode":"none","targetValue":null,"targetDate":null,"isDemoData":false}]}
        """
        XCTAssertThrowsError(try ExportService.parsePayload(Data(payload.utf8)))
    }

    func testImportRejectsDuplicateIDs() throws {
        let id = UUID().uuidString
        let payload = """
        {"app":"AssetLife","formatVersion":1,"exportedAt":"2024-01-01T00:00:00Z","assetCount":2,"assets":[{"id":"\(id)","name":"A","price":"10","purchaseDate":"2024-01-01T00:00:00Z","category":"数码","status":"inUse","kind":"asset","costMode":"perDay","useCount":0,"iconName":"x","notes":"","tags":[],"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z","targetMode":"none","targetValue":null,"targetDate":null,"isDemoData":false},{"id":"\(id)","name":"B","price":"20","purchaseDate":"2024-01-02T00:00:00Z","category":"数码","status":"inUse","kind":"asset","costMode":"perDay","useCount":0,"iconName":"x","notes":"","tags":[],"createdAt":"2024-01-02T00:00:00Z","updatedAt":"2024-01-02T00:00:00Z","targetMode":"none","targetValue":null,"targetDate":null,"isDemoData":false}]}
        """
        XCTAssertThrowsError(try ExportService.parsePayload(Data(payload.utf8)))
    }

    func testImportPreservesTargetFields() throws {
        let id = UUID().uuidString
        let payload = """
        {"app":"AssetLife","formatVersion":1,"exportedAt":"2024-01-01T00:00:00Z","assetCount":1,"assets":[{"id":"\(id)","name":"X","price":"365","purchaseDate":"2024-01-01T00:00:00Z","category":"数码","status":"inUse","kind":"asset","costMode":"perDay","useCount":0,"iconName":"x","notes":"","tags":[],"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z","targetMode":"custom","targetValue":"1.00","targetDate":null,"isDemoData":false}]}
        """
        let parsed = try ExportService.parsePayload(Data(payload.utf8))
        XCTAssertEqual(parsed.first?.targetMode, .custom)
        XCTAssertEqual(parsed.first?.resolvedTargetDailyCost(), Decimal(string: "1.00"))
    }
}
