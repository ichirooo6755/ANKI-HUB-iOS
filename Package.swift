// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ANKI-HUB-iOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ANKI-HUB-iOS",
            targets: ["ANKI-HUB-iOS"]
        )
    ],
    dependencies: [
        // Supabase SDK - uncomment after adding via Xcode:
        // .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "ANKI-HUB-iOS",
            dependencies: [
                // .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources/ANKI-HUB-iOS",
            exclude: [
                "Info.plist",
                "ANKI-HUB-iOS.entitlements",
                "Assets.xcassets",
            ],
            resources: [
                .copy("Resources/vocab1900.tsv"),
                .copy("Resources/kobun.json"),
                .copy("Resources/kanbun.json"),
                .copy("Resources/constitution.json"),
                .copy("Resources/kobun_pdf.json"),
                .copy("Resources/grammar.json"),
                .copy("Resources/Wallpapers"),
            ]
        ),
        .target(
            name: "ANKI-HUB-iOS-Widget",
            dependencies: [],
            path: "Sources/ANKI-HUB-iOS-Widget",
            exclude: [
                "Info.plist",
                "ANKI-HUB-iOS-Widget.entitlements",
            ],
            sources: [".", "../Shared"]
        ),
    ]
)
