// Direct-native entry: the same SKView + GameScene construction the wasm
// main performs, driven by an SDL frame loop instead of a browser.
import SpriteKit
import CSDL3

@main
enum Main {
    static func main() {
        Kit.shared.logicalW = 800
        Kit.shared.logicalH = 600
        kitHostInit(appName: "FrogMan")

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

        var last = SDL_GetTicksNS()
        var selftestMs: Float = 0
        var selftest: Float = 0
        if let s = ("FROGMAN_SELFTEST".withCString { SDL_getenv($0) }) {
            selftest = Float(SDL_strtod(s, nil))
        }
        var frames = 0

        while kitHostPump() {
            let now = SDL_GetTicksNS()
            var dt = Float(now - last) / 1_000_000
            last = now
            if dt > 50 { dt = 50 }

            v.tick(Double(dt))
            kitHostPresent()

            frames += 1
            if selftest > 0 {
                selftestMs += dt
                if selftestMs >= selftest * 1000 {
                    if let surf = SDL_RenderReadPixels(Kit.shared.renderer, nil) {
                        _ = "direct-selftest.bmp".withCString { SDL_SaveBMP(surf, $0) }
                        SDL_DestroySurface(surf)
                    }
                    print("selftest: \(frames) frames -> direct-selftest.bmp")
                    break
                }
            }

            let used = SDL_GetTicksNS() - now
            if used < 4_000_000 { SDL_DelayNS(2_000_000) }
        }
        SDL_Quit()
    }
}
