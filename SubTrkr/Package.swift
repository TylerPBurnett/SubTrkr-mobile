// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SubTrkr",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "SubTrkr", targets: ["SubTrkr"])
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
        )
    ]
)
