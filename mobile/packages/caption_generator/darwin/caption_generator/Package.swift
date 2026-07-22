// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "caption_generator",
  platforms: [
    .iOS("13.0"),
    .macOS("10.15"),
  ],
  products: [
    .library(name: "caption-generator", targets: ["caption_generator"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "caption_generator",
      dependencies: []
    ),
  ]
)
