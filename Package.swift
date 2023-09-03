// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TeslaKit",
    platforms: [
            .macOS(.v11), .iOS(.v14), .tvOS(.v13)
        ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TeslaKit",
            targets: ["TeslaKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/tristanhimmelman/ObjectMapper.git", .upToNextMajor(from: "4.1.0")),
		// Starscream is a conforming WebSocket (RFC 6455) library in Swift.
		.package(url: "https://github.com/daltoniam/Starscream.git", .upToNextMajor(from: "4.0.0")),
        // Polylines Decode a polyline to an array of CLLocationCoordinate2D
        .package(url: "https://github.com/raphaelmor/Polyline.git", from: "5.0.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TeslaKit",
            dependencies: ["ObjectMapper", "Starscream", "Polyline"],
            resources: [ .copy("Resources/TeslaVehicleOptionCodes.plist")])
    ]
)
