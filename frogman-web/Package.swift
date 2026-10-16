// swift-tools-version:6.2
import PackageDescription

// FrogMan, SpriteKit edition, on wasm.
//
// A port of the macOS FrogMan SpriteKit game (../FrogMan) to WebAssembly via
// the SuperBox64 SpriteKit reimplementation. The game's `import SpriteKit` /
// `import GameplayKit` / `import AVFoundation` lines work unchanged here:
// the package vends modules with those exact names. GameScene.swift is a
// symlink to the macOS master, so there is one game source.
let package = Package(
    name: "FrogManWeb",
    dependencies: [
        // TODO: switch back to the remote (branch "embedded") once the
        // SKNode Hashable + build-native-game.sh AVFoundation fixes this
        // port needed are pushed. Local path lets iteration pick them up
        // without a round-trip through GitHub.
        .package(path: "../../SuperBox64Kit"),
    ],
    targets: [
        .executableTarget(
            name: "FrogMan",
            dependencies: [
                .product(name: "SpriteKit",      package: "SuperBox64Kit"),
                .product(name: "KitABI",         package: "SuperBox64Kit"),
                .product(name: "AppKit",         package: "SuperBox64Kit"),
                .product(name: "GameplayKit",    package: "SuperBox64Kit"),
                .product(name: "GameController", package: "SuperBox64Kit"),
                .product(name: "AVFoundation",   package: "SuperBox64Kit"),
            ],
            swiftSettings: [
                // Swift 5 language mode: relaxed concurrency checking so the
                // game's SKNode subclasses compile against the kit's
                // (currently nonisolated) SpriteKit.
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xclang-linker", "-mexec-model=reactor",
                    "-Xlinker", "--export=boot",
                    "-Xlinker", "--export=frame",
                    "-Xlinker", "--export-if-defined=_initialize",
                    "-Xlinker", "--allow-undefined",
                ]),
            ]
        ),
    ]
)
