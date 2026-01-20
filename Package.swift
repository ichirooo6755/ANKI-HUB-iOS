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
                "ANKI-HUB-iOS-Shared",
                // .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources/ANKI-HUB-iOS",
            exclude: [
                "Info.plist",
                "ANKI-HUB-iOS.entitlements",
                "Assets.xcassets",
                "Views/CalendarView.swift",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "ANKI-HUB-iOS-Shared",
            path: "Sources/Shared"
        ),
        .target(
            name: "ANKI-HUB-iOS-Widget",
            dependencies: [
                "ANKI-HUB-iOS-Shared"
            ],
            path: "Sources",
            exclude: [
                "ANKI-HUB-iOS-Widget/Info.plist",
                "ANKI-HUB-iOS-Widget/ANKI-HUB-iOS-Widget.entitlements",
            ],
            sources: [
                "ANKI-HUB-iOS-Widget",
            ]
        ),
    ]
)
