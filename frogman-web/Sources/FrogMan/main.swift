import SpriteKit
import KitABI

// Reactor-mode wasm entry. The runtime calls _initialize once, then boot()
// brings up the SKView and the game scene (the same construction the macOS
// ViewController performs), and frame() advances one animation frame.

nonisolated(unsafe) var view: SKView? = nil

private func bootBody() {
    let v = SKView()
    v.ignoresSiblingOrder = false
    v.showsFPS = false
    v.showsNodeCount = false
    v.preferredFramesPerSecond = 60

    // Fixed base resolution to match the macOS ViewController, which keeps
    // stroke widths (this game draws everything with SKShapeNode) consistent.
    let scene = GameScene(size: CGSize(width: 800, height: 600))
    scene.scaleMode = .aspectFit
    v.presentScene(scene)
    view = v
}

#if hasFeature(Embedded)
@_cdecl("boot")
public func boot() { bootBody() }

@_cdecl("frame")
public func frame(_ dtMs: Double) { view?.tick(dtMs) }
#else
@_cdecl("boot")
public func boot() { MainActor.assumeIsolated { bootBody() } }

@_cdecl("frame")
public func frame(_ dtMs: Double) { MainActor.assumeIsolated { view?.tick(dtMs) } }
#endif
