// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SubTrkr",
    platforms: [
        .iOS(.v18)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SubTrkr",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "SubTrkr"
        ),
        .testTarget(
            name: "SubTrkrTests",
            dependencies: ["SubTrkr"],
            path: "Tests/SubTrkrTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
