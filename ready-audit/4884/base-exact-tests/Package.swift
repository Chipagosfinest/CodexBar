// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TypographyProof", platforms: [.macOS(.v15)], products: [.library(name: "CodexBar", targets: ["CodexBar"])], targets: [.target(name: "CodexBar"), .testTarget(name: "ProofTests", dependencies: ["CodexBar"])])
