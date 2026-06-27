// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "background_uploader",
  platforms: [
    .iOS("13.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "background-uploader", targets: ["background_uploader"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "background_uploader",
      dependencies: []
    ),
  ]
)
