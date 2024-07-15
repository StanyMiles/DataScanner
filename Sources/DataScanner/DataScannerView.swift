import SwiftUI
import Vision
import VisionKit

public struct DataScannerView: View {
  @Environment(\.screenSize) private var screenSize
  @Binding private var types: Set<DataType>
  private let qualityLevel: DataScannerViewController.QualityLevel
  private let recognizesMultipleItems: Bool
  private let isHighFrameRateTrackingEnabled: Bool
  private let isPinchToZoomEnabled: Bool
  private let isGuidanceEnabled: Bool
  private let isHighlightingEnabled: Bool
  @Binding private var isScanningActive: Bool
  private var cameraHeight: CGFloat
  private var onDetect: OnDetectScan
  @State private var cameraFrame: CGRect = .zero
  
  @MainActor
  private var isAvailable: Bool {
    DataScannerViewController.isSupported && DataScannerViewController.isAvailable
  }
  
  public init(
    types: Binding<Set<DataType>>,
    qualityLevel: DataScannerViewController.QualityLevel = .balanced,
    recognizesMultipleItems: Bool = false,
    isHighFrameRateTrackingEnabled: Bool = true,
    isPinchToZoomEnabled: Bool = true,
    isGuidanceEnabled: Bool = true,
    isHighlightingEnabled: Bool = false,
    isScanningActive: Binding<Bool>,
    cameraHeight: CGFloat,
    onDetect: @escaping OnDetectScan
  ) {
    self._types = types
    self.qualityLevel = qualityLevel
    self.recognizesMultipleItems = recognizesMultipleItems
    self.isHighFrameRateTrackingEnabled = isHighFrameRateTrackingEnabled
    self.isPinchToZoomEnabled = isPinchToZoomEnabled
    self.isGuidanceEnabled = isGuidanceEnabled
    self.isHighlightingEnabled = isHighlightingEnabled
    self._isScanningActive = isScanningActive
    self.cameraHeight = cameraHeight
    self.onDetect = onDetect
  }
  
  public var body: some View {
    #if targetEnvironment(simulator)
    noCameraView
    #else
    if isAvailable {
      DataScannerController(
        recognizedDataTypes: types,
        qualityLevel: qualityLevel,
        recognizesMultipleItems: recognizesMultipleItems,
        isHighFrameRateTrackingEnabled: isHighFrameRateTrackingEnabled,
        isPinchToZoomEnabled: isPinchToZoomEnabled,
        isGuidanceEnabled: isGuidanceEnabled,
        isHighlightingEnabled: isHighlightingEnabled,
        isScanningActive: $isScanningActive,
        cameraFrame: cameraFrame,
        onDetect: onDetect
      )
      .id([types.hashValue, screenSize.width.hashValue])
      .frame(width: screenSize.width, height: cameraHeight)
      .get(frame: $cameraFrame, in: .local)
    } else {
      noCameraView
    }
    #endif
  }
  
  private var noCameraView: some View {
    Text("Scanner not available")
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  DataScannerView(
    types: .constant([.barcode]),
    isScanningActive: .constant(false),
    cameraHeight: 300,
    onDetect: { _ in }
  )
}
