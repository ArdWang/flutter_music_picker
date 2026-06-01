// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_music_picker",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(
            name: "flutter-music-picker",
            targets: ["flutter_music_picker"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_music_picker",
            path: "../Classes",
            resources: [],
            publicHeadersPath: "."
        )
    ]
)
