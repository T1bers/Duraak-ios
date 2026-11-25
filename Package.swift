// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Durak",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "DurakCore", targets: ["DurakCore"])],
    targets: [
        .target(name: "DurakCore", path: "Durak",
                exclude: ["DurakApp.swift", "Views.swift", "GameViewModel.swift"]),
        .testTarget(name: "DurakCoreTests", dependencies: ["DurakCore"],
                    path: "Tests/DurakCoreTests")
    ]
)
