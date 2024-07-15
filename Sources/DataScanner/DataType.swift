import VisionKit

public enum DataType {
  case barcode, text
  
  var asRecognizedDataType: DataScannerViewController.RecognizedDataType {
    switch self {
      case .barcode:
        return .barcode()
      case .text:
        return .text()
    }
  }
}

extension Set where Element == DataType {
  var asRecognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> {
    Set<DataScannerViewController.RecognizedDataType>(map(\.asRecognizedDataType))
  }
}
