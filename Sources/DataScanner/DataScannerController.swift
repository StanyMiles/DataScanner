import SwiftUI
import Vision
import VisionKit

public typealias OnDetectScan = (Result<[ScanResult], Error>) -> Void

struct DataScannerController: UIViewControllerRepresentable {
  private let recognizedDataTypes: Set<DataType>
  private let qualityLevel: DataScannerViewController.QualityLevel
  private let recognizesMultipleItems: Bool
  private let isHighFrameRateTrackingEnabled: Bool
  private let isPinchToZoomEnabled: Bool
  private let isGuidanceEnabled: Bool
  private let isHighlightingEnabled: Bool
  @Binding private var isScanningActive: Bool
  private let cameraFrame: CGRect
  private var onDetect: OnDetectScan
  
  init(
    recognizedDataTypes: Set<DataType>,
    qualityLevel: DataScannerViewController.QualityLevel,
    recognizesMultipleItems: Bool,
    isHighFrameRateTrackingEnabled: Bool,
    isPinchToZoomEnabled: Bool,
    isGuidanceEnabled: Bool,
    isHighlightingEnabled: Bool,
    isScanningActive: Binding<Bool>,
    cameraFrame: CGRect,
    onDetect: @escaping OnDetectScan
  ) {
    self.recognizedDataTypes = recognizedDataTypes
    self.qualityLevel = qualityLevel
    self.recognizesMultipleItems = recognizesMultipleItems
    self.isHighFrameRateTrackingEnabled = isHighFrameRateTrackingEnabled
    self.isPinchToZoomEnabled = isPinchToZoomEnabled
    self.isGuidanceEnabled = isGuidanceEnabled
    self.isHighlightingEnabled = isHighlightingEnabled
    self._isScanningActive = isScanningActive
    self.cameraFrame = cameraFrame
    self.onDetect = onDetect
  }
  
  func makeUIViewController(context: Context) -> DataScannerViewController {
    context.coordinator.controller
  }
  
  func updateUIViewController(
    _ uiViewController: DataScannerViewController,
    context: Context
  ) {
    context.coordinator.controller.regionOfInterest = cameraFrame
    
    if isScanningActive {
      do {
        try uiViewController.startScanning()
      } catch {
        isScanningActive = false
        onDetect(.failure(error))
      }
    } else {
      uiViewController.stopScanning()
    }
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(
      recognizedDataTypes: recognizedDataTypes.asRecognizedDataTypes,
      qualityLevel: qualityLevel,
      recognizesMultipleItems: recognizesMultipleItems,
      isHighFrameRateTrackingEnabled: isHighFrameRateTrackingEnabled,
      isPinchToZoomEnabled: isPinchToZoomEnabled,
      isGuidanceEnabled: isGuidanceEnabled,
      isHighlightingEnabled: isHighlightingEnabled,
      onDetect: onDetect
    )
  }
  
  final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    let controller: DataScannerViewController
    private var onDetect: OnDetectScan
    
    init(
      recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>,
      qualityLevel: DataScannerViewController.QualityLevel,
      recognizesMultipleItems: Bool,
      isHighFrameRateTrackingEnabled: Bool,
      isPinchToZoomEnabled: Bool,
      isGuidanceEnabled: Bool,
      isHighlightingEnabled: Bool,
      onDetect: @escaping OnDetectScan
    ) {
      controller = DataScannerViewController(
        recognizedDataTypes: recognizedDataTypes,
        qualityLevel: qualityLevel,
        recognizesMultipleItems: recognizesMultipleItems,
        isHighFrameRateTrackingEnabled: isHighFrameRateTrackingEnabled,
        isPinchToZoomEnabled: isPinchToZoomEnabled,
        isGuidanceEnabled: isGuidanceEnabled,
        isHighlightingEnabled: isHighlightingEnabled
      )
      self.onDetect = onDetect
      super.init()
      controller.delegate = self
      
      NotificationCenter.default.addObserver(
        forName: .manualScanNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        self?.handleManualScan()
      }
    }
    
    func dataScanner(
      _ dataScanner: DataScannerViewController,
      didAdd addedItems: [RecognizedItem],
      allItems: [RecognizedItem]
    ) {
      onDetect(.success(addedItems.asScannedData))
    }
    
    func dataScanner(
      _ dataScanner: DataScannerViewController,
      didTapOn item: RecognizedItem
    ) {
      onDetect(.success([item].asScannedData))
    }
    
    private func handleManualScan() {
      Task {
        let photo = try await controller.capturePhoto()
        try detectData(in: photo)
      }
    }
    
    private func detectData(in photo: UIImage) throws {
      guard let cgImage = photo.cgImage else { return }
      
      let requests: [VNRequest]
      
      switch controller.recognizedDataTypes {
        case [.barcode()]:
          requests = [
            VNDetectBarcodesRequest { [self] request, error in
              guard error == nil else { return }
              let result = processClassification(request)
              guard !Task.isCancelled else { return }
              onDetect(.success(result))
            }
          ]
        case [.text()]:
          requests = [
            VNRecognizeTextRequest { [self] request, error in
              guard error == nil else { return }
              let result = processClassification(request)
              guard !Task.isCancelled else { return }
              onDetect(.success(result))
            }
          ]
        case [.barcode(), .text()], [.text(), .barcode()]:
          requests = [
            VNDetectBarcodesRequest { [self] request, error in
              guard error == nil else { return }
              let result = processClassification(request)
              guard !Task.isCancelled else { return }
              onDetect(.success(result))
            },
            VNRecognizeTextRequest { [self] request, error in
              guard error == nil else { return }
              let result = processClassification(request)
              guard !Task.isCancelled else { return }
              onDetect(.success(result))
            }
          ]
        default:
          return
      }
      
      let handler = VNImageRequestHandler(cgImage: cgImage)
      try handler.perform(requests)
    }
    
    private func processClassification(_ request: VNRequest) -> [ScanResult] {
      switch request {
        case let request as VNDetectBarcodesRequest:
          guard let observations = request.results as [VNBarcodeObservation]? else { return [] }
          return observations
            .map(\.asBarcode)
        case let request as VNRecognizeTextRequest:
          guard let observations = request.results as [VNRecognizedTextObservation]? else { return [] }
          return observations
            .compactMap(\.asTextObservation)
            .sorted { $0.confidence > $1.confidence }
            .map(\.asText)
        default:
          fatalError("Unsupported VNRequest")
      }
    }
  }
}

private extension VNBarcodeObservation {
  var asBarcode: ScanResult {
    .barcode(payloadStringValue)
  }
}

private extension VNRecognizedTextObservation {
  var asTextObservation: TextObservation? {
    guard let topObservation = topCandidates(1).first else { return nil }
    return TextObservation(
      id: uuid,
      string: topObservation.string,
      confidence: topObservation.confidence
    )
  }
}

private struct TextObservation {
  let id: UUID
  let string: String
  let confidence: VNConfidence
}

private extension TextObservation {
  var asText: ScanResult {
    .text(string)
  }
}
