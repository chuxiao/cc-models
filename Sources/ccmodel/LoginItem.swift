import Foundation
import ServiceManagement

/// 登录项（开机自启，Task 7）：SMAppService 的薄封装。注册/注销经可注入闭包
/// `setEnabledHandler` 发送（nil 时走 SMAppService 真实路径），闭包是唯一测试缝
/// （仿 Task 5 Notifier deliveryHandler 模式）。开关初值不读本类型——以
/// store.launchAtLogin 持久事实为准（控制者裁定），`isEnabled` 仅供装配层与
/// 人工核对使用。
enum LoginItem {

    /// 测试缝：非 nil 时 setEnabled 委托给它，不触达 SMAppService。
    static var setEnabledHandler: ((Bool) throws -> Void)?

    /// 开启即登记登录项（register），关闭即注销（unregister）；失败原样抛出，
    /// 由调用方回拨开关并提示（plan §5 风险项：非 /Applications 位置注册可能失败）。
    static func setEnabled(_ on: Bool) throws {
        if let setEnabledHandler {
            try setEnabledHandler(on)
            return
        }
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// 登录项当前是否已登记。
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
