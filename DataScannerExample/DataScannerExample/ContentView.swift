import DataScanner
import SwiftUI

struct ContentView: View {
  @State private var height: CGFloat = 300
  @State private var isScanning = false
  @State private var dataTypes: Set<DataType> = [.barcode]
  
  var body: some View {
    VStack(spacing: 40) {
      DataScannerView(
        types: $dataTypes,
        isScanningActive: $isScanning,
        onDetect: { result in
          print(result)
        }
      )
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
      }
    }
  }
}

#Preview {
  ContentView()
}
