// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "DataScanner",
  platforms: [
    .iOS(.v16)
  ],
  products: [
    .library(
      name: "DataScanner",
      targets: ["DataScanner"]
    ),
  ],
  targets: [
    .target(name: "DataScanner"),
    .testTarget(
      name: "DataScannerTests",
      dependencies: ["DataScanner"]
    )
  ]
)
