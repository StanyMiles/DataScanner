import SwiftUI

private struct ScreenSizeKey: EnvironmentKey {
  static let defaultValue: CGSize = .zero
}

extension EnvironmentValues {
  public var screenSize: CGSize {
    get { self[ScreenSizeKey.self] }
    set { self[ScreenSizeKey.self] = newValue }
  }
}
