// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MathronautsCore",
    products: [.library(name: "MathronautsCore", targets: ["MathronautsCore"])],
    targets: [
        .target(name: "MathronautsCore"),
        .testTarget(name: "MathronautsCoreTests", dependencies: ["MathronautsCore"])
    ]
)
