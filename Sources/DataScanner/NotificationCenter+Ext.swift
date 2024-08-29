import Foundation

extension Notification.Name {
  public static let manualScanNotification = Notification.Name("ee.adams.manual.scan.event.trigger")
  public static let manualScanResult = Notification.Name("ee.adams.manual.scan.result")
}

extension NotificationCenter {
  static func postManualScanResult(_ result: ManualScanResult) {
    switch result {
      case .success:
        NotificationCenter.default.post(name: .manualScanResult, object: nil, userInfo: ["Success": true])
      case .failure:
        NotificationCenter.default.post(name: .manualScanResult, object: nil, userInfo: ["Success": false])
    }
  }
}

extension Notification {
  public var isSuccess: Bool {
    userInfo?["Success"] as? Bool ?? false
  }
}

enum ManualScanResult {
  case success, failure
}
