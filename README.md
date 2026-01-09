# DataScanner Example App

A SwiftUI-based example app and reusable components for scanning barcodes and text using Apple's VisionKit and Vision frameworks.

## Features
- Scan barcodes and/or text in real time using the camera
- Region of interest support for focused scanning
- Manual scan trigger support
- Fully SwiftUI-compatible, with customizable scanning overlays
- Toggle scanning, modes, and preview sizes at runtime

## Technologies Used
- SwiftUI
- VisionKit (for real-time data scanning)
- Vision (for image-based detection)

## Getting Started

### Requirements
- iOS device with a camera and support for VisionKit
- Xcode 15 or later

### Running the Example App
1. Clone this repository
2. Open in Xcode
3. Build and run the `DataScannerExampleApp` target on a supported iOS device

### Usage
To use the scanner view in your own code:

```swift
import DataScanner
import SwiftUI

struct ContentView: View {
  @State private var dataTypes: Set<DataType> = [.barcode]
  @State private var isScanning = false
  @State private var regionOfInterest: CGRect?

  var body: some View {
    DataScannerView(
      types: $dataTypes,
      regionOfInterest: $regionOfInterest,
      isScanningActive: $isScanning,
      onDetect: { result in
        print(result) // Handle scan results here
      }
    )
  }
}
