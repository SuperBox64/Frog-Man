//
//  ViewController.swift
//  FrogMan
//
//  Created by SuperBox64m on 1/2/25.
//

import Cocoa
import SpriteKit
import GameplayKit

class ViewController: NSViewController {

    @IBOutlet var skView: SKView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.skView {
            // Use a fixed base resolution to maintain consistent stroke widths
            let baseSize = CGSize(width: 800, height: 600)
            let scene = GameScene(size: baseSize)
            scene.scaleMode = .aspectFit

            view.presentScene(scene)
            view.ignoresSiblingOrder = false
            //view.showsPhysics = false
            view.showsFPS = false
            view.showsNodeCount = false
        }
    }
}

