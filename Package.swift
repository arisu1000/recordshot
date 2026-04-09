// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RecordShot",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "RecordShot", targets: ["RecordShot"])
    ],
    targets: [
        .executableTarget(
            name: "RecordShot",
            path: "RecordShot",
            exclude: [
                "Info.plist",
                "RecordShot.entitlements",
                "Assets.xcassets",
                "en.lproj",
                "ko.lproj",
            ]
        ),
        .testTarget(
            name: "RecordShotTests",
            dependencies: ["RecordShot"],
            path: "RecordShotTests"
        )
    ]
)
