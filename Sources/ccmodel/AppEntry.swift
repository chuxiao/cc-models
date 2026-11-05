// 构建占位：executableTarget 在无入口点时无法链接（本机工具链多文件场景实测必失败）。
// Task 5 创建 Main.swift 时删除本文件，否则双 @main 冲突。
@main
struct AppEntry {
    static func main() {}
}
