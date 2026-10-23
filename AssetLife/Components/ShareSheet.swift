import SwiftUI
import UIKit

/// 系统分享面板封装（用于导出 JSON）。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 将 JSON 数据写入临时文件并分享。
enum ShareFileHelper {
    static func temporaryURL(fileName: String, data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
