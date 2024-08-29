import Combine
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
  @Binding private var cameraFrame: CGRect
  private var onDetect: OnDetectScan
  
  private let passthroughSubject: PassthroughSubject<[ScanResult], Never> = .init()
  private var subscriptions: Set<AnyCancellable> = .init()
  
  init(
    recognizedDataTypes: Set<DataType>,
    qualityLevel: DataScannerViewController.QualityLevel,
    recognizesMultipleItems: Bool,
    isHighFrameRateTrackingEnabled: Bool,
    isPinchToZoomEnabled: Bool,
    isGuidanceEnabled: Bool,
    isHighlightingEnabled: Bool,
    isScanningActive: Binding<Bool>,
    cameraFrame: Binding<CGRect>,
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
    self._cameraFrame = cameraFrame
    self.onDetect = onDetect
    
    // If both text and barcode are enabled,
    // manual scan will aggregate the results to send single event
    // instead of two separate ones.
    passthroughSubject
      .collect(.byTimeOrCount(DispatchQueue.global(), .seconds(2), 2))
      .sink(receiveCompletion: { subscription in
        switch subscription {
          case .finished:
            // NOP
            break
          case .failure(let failure):
            NotificationCenter.postManualScanResult(.failure)
            onDetect(.failure(failure))
        }
      }, receiveValue: { values in
        NotificationCenter.postManualScanResult(.success)
        onDetect(.success(values.flatMap { $0 }))
      })
      .store(in: &subscriptions)
  }
  
  func makeUIViewController(context: Context) -> DataScannerViewController {
    context.coordinator.controller
  }
  
  func updateUIViewController(
    _ uiViewController: DataScannerViewController,
    context: Context
  ) {
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
      cameraFrame: $cameraFrame,
      passthroughSubject: passthroughSubject,
      onDetect: onDetect
    )
  }
  
  final class Coordinator: NSObject, DataScannerViewControllerDelegate {
    let controller: DataScannerViewController
    @Binding private var cameraFrame: CGRect
    private let onDetect: OnDetectScan
    private let passthroughSubject: PassthroughSubject<[ScanResult], Never>
    
    init(
      recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>,
      qualityLevel: DataScannerViewController.QualityLevel,
      recognizesMultipleItems: Bool,
      isHighFrameRateTrackingEnabled: Bool,
      isPinchToZoomEnabled: Bool,
      isGuidanceEnabled: Bool,
      isHighlightingEnabled: Bool,
      cameraFrame: Binding<CGRect>,
      passthroughSubject: PassthroughSubject<[ScanResult], Never>,
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
      self._cameraFrame = cameraFrame
      self.passthroughSubject = passthroughSubject
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
        let photo = try await controller
          .capturePhoto()
          .fixOrientation()
          .crop(to: cameraFrame)
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
              guard error == nil else {
                NotificationCenter.postManualScanResult(.failure)
                return
              }
              let result = processClassification(request)
              guard !Task.isCancelled else { 
                NotificationCenter.postManualScanResult(.failure)
                return
              }
              guard !result.isEmpty else {
                NotificationCenter.postManualScanResult(.failure)
                return
              }
              NotificationCenter.postManualScanResult(.success)
              onDetect(.success(result))
            }
          ]
        case [.text()]:
          requests = [
            VNRecognizeTextRequest { [self] request, error in
              guard error == nil else {
                NotificationCenter.postManualScanResult(.failure)
                return
              }
              let result = processClassification(request)
              guard !Task.isCancelled else {
                NotificationCenter.postManualScanResult(.failure)
                return
              }
              guard !result.isEmpty else {
                NotificationCenter.postManualScanResult(.failure)
                return
              }
              NotificationCenter.postManualScanResult(.success)
              onDetect(.success(result))
            }
          ]
        case [.barcode(), .text()], [.text(), .barcode()]:
          requests = [
            VNDetectBarcodesRequest { [self] request, error in
              guard error == nil else { return }
              let result = processClassification(request)
              guard !Task.isCancelled else { return }
              guard !result.isEmpty else { return }
              passthroughSubject.send(result)
            },
            VNRecognizeTextRequest { [self] request, error in
              guard error == nil else { return }
              let result = processClassification(request)
              guard !Task.isCancelled else { return }
              guard !result.isEmpty else { return }
              passthroughSubject.send(result)
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

private extension UIImage {
  func fixOrientation() -> UIImage {
    // TODO: handle for landscape orientation
    if imageOrientation == .up {  return self }
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    draw(in: CGRect(
      origin: .zero,
      size: size
    ))
    guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
      return self
    }
    UIGraphicsEndImageContext()
    return normalizedImage
  }
  
  func crop(to frame: CGRect) -> UIImage {
    let widthScale = size.width / frame.width
    let newHeight = frame.height * widthScale
    let y = size.height / 2 - newHeight / 2
    
    let cropFrame = CGRect(
      origin: CGPoint(x: .zero, y: y),
      size: CGSize(width: size.width, height: newHeight)
    )
    
    guard let cgCroppedImage = cgImage?.cropping(to: cropFrame) else {
      return self
    }
    return UIImage(
      cgImage: cgCroppedImage,
      scale: scale,
      orientation: imageOrientation
    )
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
