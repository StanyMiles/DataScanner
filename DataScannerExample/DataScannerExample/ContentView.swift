import DataScanner
import SwiftUI

struct ContentView: View {
  @State private var height: CGFloat = 300
  @State private var isScanning = false
  @State private var dataTypes: Set<DataType> = [.barcode]
  @State private var regionOfInterest: CGRect?
  
  var body: some View {
    VStack(spacing: 40) {
      DataScannerView(
        types: $dataTypes,
        regionOfInterest: $regionOfInterest,
        isScanningActive: $isScanning,
        onDetect: { result in
          print(result)
        }
      )
      .overlay {
        Rectangle()
          .fill(.red.opacity(0.2))
          .frame(width: 200, height: 100)
          .background {
            GeometryReader { geo in
              Color.clear
                .preference(
                  key: CameraFramePreferenceKey.self,
                  value: geo.frame(in: .named("CameraSpace"))
                )
                .onPreferenceChange(CameraFramePreferenceKey.self) { frame in
                  self.regionOfInterest = frame
                }
            }
          }
      }
      .frame(height: height)
      .background(Color.green)
      Spacer() 
      HStack(spacing: 40) {
        Button("Toggle size") {
          if height == 300 {
            height = 500
          } else {
            height = 300
          }
        }
        .frame(height: 44)
        
        Button(isScanning ? "Stop scanning" : "Start scanning") {
          isScanning.toggle()
        }
        .frame(height: 44)
      }
      
      Button("Manual scan") {
        NotificationCenter.default.post(name: .manualScanNotification, object: nil)
      }
      .frame(height: 44)
      
      HStack(spacing: 40) {
        Button("Scan text") {
          dataTypes = [.text]
        }
        .frame(height: 44)
        
        Button("Scan barcodes") {
          dataTypes = [.barcode]
        }
        .frame(height: 44)
        
        Button("Scan both") {
          dataTypes = [.barcode, .text]
        }
        .frame(height: 44)
      }
    }
    .coordinateSpace(.named("CameraSpace"))
  }
}

#Preview {
  ContentView()
}

private struct CameraFramePreferenceKey: PreferenceKey {
  static var defaultValue: CGRect = .zero
  
  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}
