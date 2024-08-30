import SwiftUI
import Vision
import VisionKit

public struct DataScannerView: View {
  @Binding private var types: Set<DataType>
  private let qualityLevel: DataScannerViewController.QualityLevel
  private let recognizesMultipleItems: Bool
  private let isHighFrameRateTrackingEnabled: Bool
  private let isPinchToZoomEnabled: Bool
  private let isGuidanceEnabled: Bool
  private let isHighlightingEnabled: Bool
  @Binding private var regionOfInterest: CGRect?
  @Binding private var isScanningActive: Bool
  private let scannerNotAvailableMessage: LocalizedStringKey
  private let scannerNotAvailableMessageColor: Color
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
    regionOfInterest: Binding<CGRect?> = .constant(nil),
    isScanningActive: Binding<Bool>,
    scannerNotAvailableMessage: LocalizedStringKey = "Scanner not available",
    scannerNotAvailableMessageColor: Color = .primary,
    onDetect: @escaping OnDetectScan
  ) {
    self._types = types
    self.qualityLevel = qualityLevel
    self.recognizesMultipleItems = recognizesMultipleItems
    self.isHighFrameRateTrackingEnabled = isHighFrameRateTrackingEnabled
    self.isPinchToZoomEnabled = isPinchToZoomEnabled
    self.isGuidanceEnabled = isGuidanceEnabled
    self.isHighlightingEnabled = isHighlightingEnabled
    self._regionOfInterest = regionOfInterest
    self._isScanningActive = isScanningActive
    self.scannerNotAvailableMessage = scannerNotAvailableMessage
    self.scannerNotAvailableMessageColor = scannerNotAvailableMessageColor
    self.onDetect = onDetect
  }
  
  public var body: some View {
    content
      .background {
        GeometryReader { geo in
          Color.clear
            .preference(
              key: CameraFramePreferenceKey.self,
              value: geo.frame(in: .global)
            )
            .onPreferenceChange(CameraFramePreferenceKey.self) { frame in
              self.cameraFrame = frame
            }
        }
      }
      .id([types.hashValue, cameraFrame.width.hashValue])
  }
  
  @MainActor
  @ViewBuilder
  private var content: some View {
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
        cameraFrame: $cameraFrame, 
        regionOfInterest: $regionOfInterest,
        onDetect: onDetect
      )
    } else {
      noCameraView
    }
    #endif
  }
  
  private var noCameraView: some View {
    Text(scannerNotAvailableMessage)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .foregroundStyle(scannerNotAvailableMessageColor)
  }
}

private struct CameraFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .zero
  
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}

#Preview {
  DataScannerView(
    types: .constant([.barcode]),
    isScanningActive: .constant(false),
    onDetect: { _ in }
  )
}
