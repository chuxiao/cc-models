import Foundation
import UserNotifications

/// 切换结果系统通知（Task 5）：文案逐字，经注入闭包 `deliveryHandler` 发送
/// （nil 时走系统通知），闭包是唯一测试缝。
///
/// 授权规则：首次走系统路径前请求授权恰一次；被拒后不再请求、不再发送、不报错。
/// 授权请求路径不可注入，无单测断言，由 verification.md S11 人工核对。
final class Notifier: NSObject {

    var deliveryHandler: ((String) -> Void)?

    func postSwitchSuccess(modelName: String) {
        post("已切换到\(modelName)，对新建会话生效")
    }

    func postSwitchFailure(modelName: String) {
        post("切换到\(modelName)失败，已保留原配置")
    }

    // MARK: - 发送

    private func post(_ text: String) {
        if let deliveryHandler {
            deliveryHandler(text)
            return
        }
        postViaSystem(text)
    }

    private enum AuthorizationState {
        case notRequested
        case requested
        case denied
    }

    private var authorizationState = AuthorizationState.notRequested
    private var isCenterConfigured = false

    private func postViaSystem(_ text: String) {
        // 无 bundle 的裸进程（swift run 等）拿不到通知中心，静默降级为不发送。
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        if !isCenterConfigured {
            isCenterConfigured = true
            center.delegate = self
        }
        switch authorizationState {
        case .denied:
            return
        case .requested:
            deliver(text, to: center)
        case .notRequested:
            authorizationState = .requested
            center.requestAuthorization(options: [.alert]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard granted else {
                        self.authorizationState = .denied
                        return
                    }
                    self.deliver(text, to: UNUserNotificationCenter.current())
                }
            }
        }
    }

    private func deliver(_ text: String, to center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "CC Model"
        content.body = text
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}

/// 菜单栏应用常驻后台，主动声明横幅呈现，避免系统因「应用在前台」而不展示。
extension Notifier: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) -> UNNotificationPresentationOptions {
        [.banner]
    }
}
