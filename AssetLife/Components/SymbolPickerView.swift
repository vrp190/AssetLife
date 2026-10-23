import SwiftUI

/// 图标选择器：精选 SF Symbols 网格。不依赖外部图标库。
struct SymbolPickerView: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    private let symbols: [(name: String, title: String)] = [
        ("cube.box.fill", "物品"),
        ("laptopcomputer", "电脑"),
        ("keyboard", "键盘"),
        ("headphones", "耳机"),
        ("display", "显示器"),
        ("camera.fill", "相机"),
        ("iphone", "手机"),
        ("applewatch", "手表"),
        ("gamecontroller.fill", "游戏机"),
        ("bed.double.fill", "床"),
        ("sofa.fill", "沙发"),
        ("lamp.desk.fill", "台灯"),
        ("fork.knife", "厨具"),
        ("cup.and.saucer.fill", "杯具"),
        ("washer", "洗衣机"),
        ("refrigerator", "冰箱"),
        ("bicycle", "自行车"),
        ("car.fill", "汽车"),
        ("figure.run", "运动"),
        ("dumbbell.fill", "健身"),
        ("tent.fill", "露营"),
        ("guitars.fill", "乐器"),
        ("pianokeys.inverse", "键盘乐器"),
        ("books.vertical.fill", "图书"),
        ("puzzlepiece.fill", "玩具"),
        ("tshirt.fill", "服饰"),
        ("heart.fill", "健康"),
        ("cross.case.fill", "医疗"),
        ("briefcase.fill", "办公"),
        ("studentdesk", "书桌"),
        ("paintbrush.fill", "绘画"),
        ("wrench.and.screwdriver.fill", "工具"),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(symbols, id: \.name) { symbol in
                        Button {
                            selected = symbol.name
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: symbol.name)
                                    .font(.system(size: 22, weight: .medium))
                                    .frame(height: 30)
                                Text(symbol.title)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selected == symbol.name ? Brand.accent.opacity(0.25) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selected == symbol.name ? Brand.accentDeep : Brand.cardStroke, lineWidth: selected == symbol.name ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol.title)
                    }
                }
                .padding(16)
            }
            .background(Brand.background)
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .accessibilityLabel("取消选择图标")
                }
            }
        }
    }
}
