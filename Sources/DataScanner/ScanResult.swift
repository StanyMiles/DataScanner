import VisionKit

public enum ScanResult {
  case text(String)
  case barcode(String?)
}

extension RecognizedItem {
  var asScannedData: ScanResult {
    switch self {
      case .text(let text):
        return .text(text.transcript)
      case .barcode(let barcode):
        return .barcode(barcode.payloadStringValue)
      @unknown default:
        fatalError("Not implemented")
    }
  }
}

extension Array where Element == RecognizedItem {
  var asScannedData: [ScanResult] { map(\.asScannedData) }
}
