//
//  GameScene.swift
//  FrogMan
//
//  Created by SuperBox64m on 1/2/25.
//

import SpriteKit
import GameplayKit
import AVFoundation
import AppKit

// Add at top of file
enum GameState {
    case title
    case playing
    case gameOver
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // Physics categories
    struct PhysicsCategory {
        static let none      : UInt32 = 0
        static let player    : UInt32 = 0b1
        static let obstacle  : UInt32 = 0b10
        static let platform  : UInt32 = 0b100
        static let baseline  : UInt32 = 0b1000
        static let ground    : UInt32 = 0b10000
        static let ringLeft  : UInt32 = 0b100000
        static let ringRight : UInt32 = 0b1000000
        static let rainbow   : UInt32 = 0b10000000
        static let killLine  : UInt32 = 0b100000000  // Add new category
        // Was PhysicsCategory.obstacle (shared with balls) — since the death
        // zones sit at the same y as the baseline, Box2D reports a real contact
        // between them, which the "ball hit baseline" handler (matching on
        // .obstacle) misidentified as a ball and deleted via removeBall(). A
        // dedicated bit keeps death-zone contacts out of every ball-shaped
        // collision check below.
        static let deathZone : UInt32 = 0b1000000000
    }
    
    // Player dimensions
    private let playerSize = CGSize(width: 25, height: 35)
    
    // Game nodes
    private var player: SKShapeNode!
    private var platforms: [SKShapeNode] = []
    private var triangles: [SKShapeNode] = []
    private var basketballs: [SKShapeNode] = []
    
    // Game state
    private var isJumping = false
    private var canShoot = true
    private var score = 0
    private var scoreLabel: SKLabelNode!
    
    // Platform constants
    private let platformSpacing: CGFloat = 0.125
    
    // Jump forces
    struct JumpForce {
        // Standing jump - increase significantly
        static let standingVertical: CGFloat = 600    // Increased from 500
        static let standingHorizontal: CGFloat = 0
        
        // Running jump - adjust proportionally
        static let runningVertical: CGFloat = 450     // Increased from 350
        static let runningHorizontal: CGFloat = 100   // Keep horizontal momentum
    }
    
    // Add this property at the top with other properties
    private let moveSpeed: CGFloat = 200.0
    private let maxGapsPerPlatform = 3 // Maximum number of gaps per platform
    private var isMovingLeft = false
    private var isMovingRight = false
    private let platformHeight: CGFloat = 15.0
    private let minPlatformWidth: CGFloat = 80.0 // Smaller minimum platform width
    private let platformSlope: CGFloat = 0.05 // Consistent slope for rolling
    private var lastUpdateTime: TimeInterval = 0
    private var isUpPressed = false
    
    // Add color constants at the top
    private let uniformBrown = NSColor.brown
    
    // At the top of the class with other constants
    private let platformHeights: [CGFloat] = [0.2, 0.35, 0.5, 0.65, 0.8]
    
    // Add to class properties
    private var lives = 5
    private var livesLabel: SKLabelNode!
    private var lastPlatformY: CGFloat = 0  // Track last platform player touched
    private var lastPlatformX: CGFloat = 0  // Track last platform section player touched
    private var scoredBalls: Set<SKShapeNode> = []  // Track balls we've scored points for
    private let ballDetectionRadius: CGFloat = 100
    private var scoredPlatforms: Set<SKNode> = []  // Track platforms we've scored points for
    private var currentLevel = 1
    private var levelLabel: SKLabelNode!
    
    // Add property to track if we're currently spawning
    private var isSpawningBall = false
    
    // Constants for positioning
    private let baselineHeight: CGFloat = 20  // Increased from 5 to 20
    private let playerStartHeight: CGFloat = 40  // Height above baseline
    
    // Add property to store spawn points
    private var spawnPoints: [(x: CGFloat, y: CGFloat)] = []
    
    // Constants for player movement
    private let jumpForce: CGFloat = -400  // Increase jump force (negative because y-axis is inverted)
    private let groundHeight: CGFloat = 30  // Increase height above baseline
    
    // Add at top of class
    private var isHandlingCollision = false
    
    // Add property for ground line
    private var canJump = false
    
    // Add property at top of class
    private var baselineScored = false
    
    // Add property to track active spawn points
    // Using string representation for Big Sur compatibility (CGPoint.Hashable requires macOS 15.0+)
    private var activeSpawnPoints: Set<String> = []
    
    // Add these properties at the top of the class
    private var totalPlatforms = 0  // Track total platforms that need to be green
    private var totalIndicators = 0  // Track total indicators that need to be gray
    
    // Add these properties at the top of the class
    private var lastPlayerY: CGFloat = 0  // Track player's last Y position
    private var ballsBeingJumpedOver: Set<SKShapeNode> = []  // Track balls we're currently jumping over
    private var jumpedBalls: Set<SKShapeNode> = []  // Track balls we've already jumped over
    
    // Add property to track which indicators have active balls
    private var indicatorsWithActiveBalls: Set<SKNode> = []
    
    // Add property to track indicator cooldowns
    private var indicatorCooldowns: [SKNode: TimeInterval] = [:]
    private let spawnCooldown: TimeInterval = 4.0  // 4 seconds cooldown
    
    // Add property at top of class
    private var gameStarted = false
    
    // At top of class with other properties
    private let vectorLetters: [String: [CGPoint]] = [
        "F": [CGPoint(x: 0, y: 100), CGPoint(x: 40, y: 100),
               CGPoint(x: 0, y: 100), CGPoint(x: 0, y: 0),
              CGPoint(x: 0, y: 50), CGPoint(x: 30, y: 50)],
        
        "R": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100),
               CGPoint(x: 0, y: 100), CGPoint(x: 30, y: 100),
               CGPoint(x: 30, y: 100), CGPoint(x: 40, y: 80),
               CGPoint(x: 40, y: 80), CGPoint(x: 40, y: 60),
               CGPoint(x: 40, y: 60), CGPoint(x: 30, y: 50),
               CGPoint(x: 30, y: 50), CGPoint(x: 0, y: 50),
              CGPoint(x: 15, y: 50), CGPoint(x: 40, y: 0)],
        
        "O": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100),
               CGPoint(x: 0, y: 100), CGPoint(x: 40, y: 100),
               CGPoint(x: 40, y: 100), CGPoint(x: 40, y: 0),
              CGPoint(x: 40, y: 0), CGPoint(x: 0, y: 0)],
        
        "G": [CGPoint(x: 0, y: 0), CGPoint(x: 40, y: 0),
               CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100),
               CGPoint(x: 0, y: 100), CGPoint(x: 40, y: 100),
               CGPoint(x: 40, y: 60), CGPoint(x: 20, y: 60),
              CGPoint(x: 40, y: 60), CGPoint(x: 40, y: 0)],
        
        "M": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100),
               CGPoint(x: 0, y: 100), CGPoint(x: 20, y: 50),
               CGPoint(x: 20, y: 50), CGPoint(x: 40, y: 100),
              CGPoint(x: 40, y: 100), CGPoint(x: 40, y: 0)],
        
        "A": [CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 100),
               CGPoint(x: 20, y: 100), CGPoint(x: 40, y: 0),
              CGPoint(x: 10, y: 50), CGPoint(x: 30, y: 50)],
        
        "N": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100),
               CGPoint(x: 0, y: 100), CGPoint(x: 40, y: 0),
              CGPoint(x: 40, y: 0), CGPoint(x: 40, y: 100)],
               
        "P": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100),
               CGPoint(x: 0, y: 100), CGPoint(x: 40, y: 100),
               CGPoint(x: 40, y: 100), CGPoint(x: 40, y: 50),
              CGPoint(x: 40, y: 50), CGPoint(x: 0, y: 50)],
               
        "S": [CGPoint(x: 40, y: 100), CGPoint(x: 0, y: 100),
               CGPoint(x: 0, y: 100), CGPoint(x: 0, y: 50),
               CGPoint(x: 0, y: 50), CGPoint(x: 40, y: 50),
               CGPoint(x: 40, y: 50), CGPoint(x: 40, y: 0),
              CGPoint(x: 40, y: 0), CGPoint(x: 0, y: 0)],
               
        "C": [CGPoint(x: 40, y: 0), CGPoint(x: 0, y: 0),
               CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100),
              CGPoint(x: 0, y: 100), CGPoint(x: 40, y: 100)],
               
        "E": [CGPoint(x: 40, y: 0), CGPoint(x: 0, y: 0),
               CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 100),
               CGPoint(x: 0, y: 100), CGPoint(x: 40, y: 100),
              CGPoint(x: 0, y: 50), CGPoint(x: 30, y: 50)],
               
        "T": [CGPoint(x: 20, y: 0), CGPoint(x: 20, y: 100),
              CGPoint(x: 0, y: 100), CGPoint(x: 40, y: 100)],
               
        "V": [CGPoint(x: 0, y: 100), CGPoint(x: 20, y: 0),
              CGPoint(x: 20, y: 0), CGPoint(x: 40, y: 100)],
        
        " ": [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0)]  // Empty space
    ]
    
    // Add these properties at the top of the class
    private let baselineLineWidth: CGFloat = 2.0
    private let deathZoneWidth: CGFloat = 50.0
    private let deathZoneSpacing: CGFloat = 25.0  // 25 pixels between red zones
    
    // Add at top of class
    private let spawnCooldownTime: TimeInterval = 2.0  // Time before location can be reused
    private var recentSpawnLocations: [(point: CGPoint, timestamp: TimeInterval)] = []
    
    // Add at top of class with other properties
    private let maxBalls = 6
    private var currentBallCount = 0
    
    // Add at top of file
    private let soundFiles: [String: String] = [
        "jump": "jump_07.wav",
        "land":
            "sfx_movement_jump16_landing.wav",
        "platformGreen": "platform_green.mp3",
        "platformYellow": "platform_yellow.mp3",
        "ballSpawn": "ball_spawn.mp3",
        "ballCollect": "ball_collect.mp3",
        "ballImplosion": "ball_implosion.mp3",
        "death": "death.wav",
        "levelComplete": "level_complete.mp3",
        "gameOver": "game_over.wav",
        "score": "score.mp3",
        "bgMusic": "bgMusic.wav"
    ]
    
    // Audio properties
    private lazy var gameAudioEngine: AVAudioEngine = {
        let engine = AVAudioEngine()
        return engine
    }()
    private var audioPlayers: [String: AVAudioPlayerNode] = [:]
    private var audioFiles: [String: AVAudioFile] = [:]
    private var audioBuffers: [String: AVAudioPCMBuffer] = [:]
    private var mainMixer: AVAudioMixerNode!
    
    // Replace setupSounds with new implementation
    private func setupSounds() {
        // Initialize audio engine
        mainMixer = gameAudioEngine.mainMixerNode
        
        // Load all sounds
        for (key, filename) in soundFiles {
            if let url = Bundle.main.url(forResource: filename.components(separatedBy: ".")[0],
                                       withExtension: filename.components(separatedBy: ".")[1]) {
                do {
                    // Create audio file
                    let audioFile = try AVAudioFile(forReading: url)
                    audioFiles[key] = audioFile
                    
                    // Create buffer
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                      frameCapacity: AVAudioFrameCount(audioFile.length)) else {
                        continue
                    }
                    try audioFile.read(into: buffer)
                    audioBuffers[key] = buffer
                    
                    // Create player node
                    let player = AVAudioPlayerNode()
                    gameAudioEngine.attach(player)
                    
                    // Connect player to main mixer
                    gameAudioEngine.connect(player, to: mainMixer, format: buffer.format)
                    
                    audioPlayers[key] = player
                } catch {
                    print("Error loading sound \(key)")
                }
            }
        }

        // Start audio engine
        do {
            try gameAudioEngine.start()
        } catch {
            print("Error starting audio engine")
        }
    }
    
    // Replace playSound with new implementation
    private func playSound(_ key: String) {
        guard let player = audioPlayers[key],
              let buffer = audioBuffers[key] else {
            return
        }
        
        // Special handling for background music and game over
        if key == "bgMusic" {
            player.pan = 0  // Center the background music
            player.volume = 0.3  // 30% volume
            player.stop()
            player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            player.play()
            return
        }
        
        if key == "gameOver" {
            player.pan = 0  // Center the game over sound
            player.volume = 0.5  // 50% volume
            player.stop()
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            player.play()
            return
        }
        
        // Calculate pan and volume based on player position relative to screen center
        if let playerNode = self.player {
            let screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
            let playerX = playerNode.position.x
            let playerY = playerNode.position.y
            
            // Calculate horizontal position relative to center (-1 to 1)
            let normalizedX = (playerX - screenCenter.x) / (size.width / 2)
            
            // Calculate vertical position relative to center (-1 to 1)
            let normalizedY = (playerY - screenCenter.y) / (size.height / 2)
            
            // Pan calculation (left to right)
            player.pan = Float(max(-1, min(1, normalizedX)))
            
            // Volume calculation based on vertical position
            // Center is full volume, edges are quieter
            let distanceFromCenter = abs(normalizedY)
            let baseVolume: Float = 1.0
            let volumeAttenuation = Float(distanceFromCenter) * 0.5  // 50% reduction at edges
            player.volume = baseVolume - volumeAttenuation
        }
        
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }
    
    // Replace stopSound with new implementation
    private func stopSound(_ key: String) {
        audioPlayers[key]?.stop()
    }
    
    // Add cleanup method
    deinit {
        gameAudioEngine.stop()
    }
    
    private func startBackgroundMusic() {
        playSound("bgMusic")
    }
    
    private func stopBackgroundMusic() {
        stopSound("bgMusic")
    }
    
    override func sceneDidLoad() {
        super.sceneDidLoad()

        // Basic scene setup
        backgroundColor = .black
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)

        // Debug visualization
        view?.showsPhysics = false
        view?.showsFPS = false
        view?.showsNodeCount = false

        // Scene physics
        let edgeLoop = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        self.physicsBody = edgeLoop
        self.physicsBody?.friction = 0
        self.physicsBody?.restitution = 0.0
        self.physicsBody?.categoryBitMask = PhysicsCategory.ground
        self.physicsBody?.collisionBitMask = PhysicsCategory.obstacle
        self.physicsBody?.contactTestBitMask = PhysicsCategory.player

        // Show title screen
        showTitleScreen()

        // Adjust line widths for initial scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.adjustLineWidthsForScale()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Adjust all line widths to compensate for scene scaling
        adjustLineWidthsForScale()
    }

    private func adjustLineWidthsForScale() {
        guard let view = view else { return }

        // Calculate the effective scale factor
        let scaleX = view.bounds.width / size.width
        let scaleY = view.bounds.height / size.height
        let effectiveScale = min(scaleX, scaleY) // Use min for aspectFit

        // Recursively adjust all SKShapeNode line widths in the scene
        adjustLineWidthsRecursively(node: self, scale: effectiveScale)
    }

    private func adjustLineWidthsRecursively(node: SKNode, scale: CGFloat) {
        if let shapeNode = node as? SKShapeNode {
            // Get the original line width from userData, or store it if not present
            #if hasFeature(Embedded)
            if let originalWidth = shapeNode.userData?["originalLineWidth"]?.cgFloatValue {
                shapeNode.lineWidth = originalWidth / scale
            } else {
                // First time - store the original width
                shapeNode.userData = shapeNode.userData ?? NSMutableDictionary()
                shapeNode.userData?["originalLineWidth"] = .double(Double(shapeNode.lineWidth))
                shapeNode.lineWidth = shapeNode.lineWidth / scale
            }
            #else
            if let originalWidth = shapeNode.userData?["originalLineWidth"] as? CGFloat {
                shapeNode.lineWidth = originalWidth / scale
            } else {
                // First time - store the original width
                shapeNode.userData = shapeNode.userData ?? NSMutableDictionary()
                shapeNode.userData?["originalLineWidth"] = shapeNode.lineWidth
                shapeNode.lineWidth = shapeNode.lineWidth / scale
            }
            #endif
        }

        // Recursively process all children
        for child in node.children {
            adjustLineWidthsRecursively(node: child, scale: scale)
        }
    }
    
    private func showTitleScreen() {
        // Create FROGMAN text node first
        let titleNode = createVectorText("FROGMAN", 
                                       position: .zero,  // Temporary position
                                       color: .green,
                                       scale: 1.0)
        
        // Center horizontally using the node's actual width
        let frogmanX = frame.midX - (titleNode.calculateAccumulatedFrame().width / 2)
        titleNode.position = CGPoint(x: frogmanX, y: frame.midY + 50)
        titleNode.name = "titleScreen"
        addChild(titleNode)
        
        // Create SPACE TO START text node
        let startText = createVectorText("SPACE TO START",
                                       position: .zero,  // Temporary position
                                       color: .white,
                                       scale: 0.5)
        
        // Center horizontally using the node's actual width
        let spaceToStartX = frame.midX - (startText.calculateAccumulatedFrame().width / 2)
        startText.position = CGPoint(x: spaceToStartX, y: frame.midY - 50)
        startText.name = "titleScreen"
        addChild(startText)
    }
    
    private func startGame() {
        setupSounds()
        startBackgroundMusic()
        // Remove title screen
        children.filter { $0.name == "titleScreen" }.forEach { $0.removeFromParent() }
        
        // Create score labels FIRST
        setupScore()
        
        // Create player
        setupPlayer()

        // Set initial level
        currentLevel = 1
        
        // Now setup the level (which uses the labels)
        setupLevel()
        
        gameStarted = true
    }
    
    // Add this function to handle common setup
    private func setupLevel() {
        // Reset extra life flag for new level
        hasExtraLifeForLevel = false
        
        // Get player's current position if they exist
        let safeZone = CGRect(
            x: player?.position.x ?? 0 - playerSize.width,
            y: player?.position.y ?? 0 - playerSize.height,
            width: playerSize.width * 2,
            height: playerSize.height * 2
        )
        
        // Clear any existing platforms/obstacles
        platforms.forEach { $0.removeFromParent() }
        platforms.removeAll()
        
        // Create new platforms, avoiding player's safe zone
        createPlatformsForLevel(avoidingZone: safeZone)
        
        // 1. Remove ALL existing nodes except player and score labels
        // Reference identity (===), not the custom Equatable conformance (==)
        // -- keeps this robust regardless of protocol-witness dispatch quirks.
        children.forEach { node in
            if node !== player &&
               node !== scoreLabel &&
               node !== livesLabel &&
               node !== levelLabel {
                node.removeFromParent()
            }
        }
        
        // Clear all arrays and tracking
        platforms.removeAll()
        basketballs.removeAll()
        scoredPlatforms.removeAll()
        
        // Reset counters
        totalPlatforms = 0
        
        // 2. Setup platforms first
        setupPlatforms()
        
        // 3. Reset player position if player exists
        if player == nil {
            setupPlayer()
        } else {
        player.position = CGPoint(x: size.width * 0.05, y: playerSize.height/2)
        player.physicsBody?.velocity = .zero
        }
        
        // 4. Start continuous ball spawning
        isSpawningBall = false  // Reset the flag
        spawnReplacementBall()  // This will start the continuous spawn cycle
        
        // 5. Reset state
        baselineScored = false
        
        // 6. Update level display if label exists
        if levelLabel == nil {
            setupScore() // Create labels if they don't exist
        }
        
        // Add baseline with death zones
        createBaselineWithDeathZones()
    }

    private func createPlatformsForLevel(avoidingZone: CGRect) {
        // Create platforms at different heights
        for height in platformHeights {
            let platformY = size.height * height
            var currentX: CGFloat = 0
            
            while currentX < size.width {
                let sectionWidth = size.width * CGFloat.random(in: 0.1...0.2)
                let platformSection = CGRect(
                    x: currentX,
                    y: platformY,
                    width: sectionWidth,
                    height: platformHeight
                )
                
                // Only create platform if it doesn't intersect with safe zone
                if !platformSection.intersects(avoidingZone) {
                    createPlatformSection(from: currentX,
                                       to: currentX + sectionWidth,
                                       at: platformY,
                                       slope: CGFloat.random(in: -platformSlope...platformSlope))
                }
                
                currentX += sectionWidth + (size.width * CGFloat.random(in: 0.05...0.1))
            }
        }
    }

    // New function to handle ball replacement with delay
    private func spawnReplacementBall() {
        // When red indicator appears
        playSound("ballSpawn")
        if isSpawningBall { return }  // Only prevent multiple spawn sequences
        if currentBallCount >= maxBalls { return }  // Don't spawn if at max
        
        isSpawningBall = true
        
        // Random delay between 1-3 seconds for next spawn sequence
        let randomDelay = TimeInterval.random(in: 1...3)
        
        // Create and run delayed spawn action
        let waitAction = SKAction.wait(forDuration: randomDelay)
        let spawnAction = SKAction.run { [self] in
            // Double check we still need a ball
            if self.currentBallCount >= self.maxBalls {
                self.isSpawningBall = false
                return
            }
            
            let randomX = CGFloat.random(in: size.width * 0.1...size.width * 0.9)
            
            // Create spawn indicator line first
            let spawnLine = SKShapeNode(rectOf: CGSize(width: 20, height: 10))
            spawnLine.position = CGPoint(x: randomX, y: self.size.height * 0.9)
            spawnLine.fillColor = .clear
            spawnLine.strokeColor = .red
            spawnLine.lineWidth = 2
            spawnLine.name = "spawnLine"
            self.addChild(spawnLine)
            
            // Changed from 3 seconds to 1 second wait time
            let spawnBallAction = SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.run {
                    // Final check before spawning
                    if self.currentBallCount < self.maxBalls {
                        // Create new ball at the EXACT indicator position
                        let newBasketball = self.createBasketball()
                        newBasketball.position = spawnLine.position
                    self.addChild(newBasketball)
                    self.basketballs.append(newBasketball)
                        self.currentBallCount += 1
                        
                        // Record spawn location
                        self.recentSpawnLocations.append((
                            point: spawnLine.position,
                            timestamp: Date().timeIntervalSince1970
                        ))
                    }
                    spawnLine.removeFromParent()
                }
            ])
            spawnLine.run(spawnBallAction)
            
            isSpawningBall = false
        }
        
        self.run(SKAction.sequence([waitAction, spawnAction]))
    }
    
    private func setupPlatforms() {
        // Reset counters at start of level
        totalPlatforms = 0
        
        // Create 4 platforms with heights reduced by 5 pixels each (~1% of screen height)
        let platformHeights: [CGFloat] = [
            0.2,  // Bottom platform
            0.4,  // Second platform
            0.6,  // Third platform
            0.8   // Top platform
        ]
        
        // Create array of required hole counts for each level
        var holeCounts = [2, 2, 3]  // First three levels
        // Top level (index 3) always has 3-4 holes
        let topLevelHoles = Int.random(in: 3...4)
        holeCounts.append(topLevelHoles)
        
        print("Level \(currentLevel) platform heights: \(platformHeights)")
        
        // Create platform sections with random angles
        for (index, height) in platformHeights.enumerated() {
            let platformY = size.height * height
            var holePositions: [(start: CGFloat, width: CGFloat)] = []
            
            // Use the pre-determined number of holes for this level
            let targetHoles = holeCounts[index]
            print("Creating \(targetHoles) holes for platform at height \(height)")
            
            // Divide platform into sections to ensure spread
            let platformWidth = size.width * 0.7  // Use 70% of screen width for holes
            let sectionWidth = platformWidth / CGFloat(targetHoles)
            
            for section in 0..<targetHoles {
                let sectionStart = size.width * 0.15 + sectionWidth * CGFloat(section)
                let holeWidth = size.width * CGFloat.random(in: 0.08...0.1)  // 8-10% of screen width
                
                // Place hole within its section
                let minX = sectionStart + sectionWidth * 0.1  // 10% buffer at start
                let maxX = sectionStart + sectionWidth * 0.9 - holeWidth  // 10% buffer at end
                let holeStart = CGFloat.random(in: minX...maxX)
                
                    holePositions.append((start: holeStart, width: holeWidth))
            }
            
            holePositions.sort { $0.start < $1.start }
            
            // Create platform sections between holes with random slopes
            var currentX: CGFloat = 0
            
            for hole in holePositions {
                if hole.start > currentX {
                    let randomSlope = CGFloat.random(in: -0.1...0.1)
                    createPlatformSection(from: currentX, to: hole.start, at: platformY, slope: randomSlope)
                }
                currentX = hole.start + hole.width
            }
            
            // Final section
            if currentX < size.width {
                let randomSlope = CGFloat.random(in: -0.1...0.1)
                createPlatformSection(from: currentX, to: size.width, at: platformY, slope: randomSlope)
            }
        }
        
        print("Created \(totalPlatforms) platform sections")
    }
    
    @discardableResult
    private func createPlatformSection(from startX: CGFloat, to endX: CGFloat, at height: CGFloat, slope: CGFloat) -> SKShapeNode {
        let platform = SKShapeNode()
        let path = CGMutablePath()
        
        // Wave parameters for a gentle wave
        let amplitude: CGFloat = 6.0  // Height of the wave
        let frequency: CGFloat = 0.01  // Length of the wave
        
        // Create points for the wave
        var points: [CGPoint] = []
        let numPoints = 30
        
        // Generate wave points
        for i in 0...numPoints {
            let x = startX + (endX - startX) * CGFloat(i) / CGFloat(numPoints)
            let progress = CGFloat(i) / CGFloat(numPoints)
            let baseY = height + (endX - startX) * slope * progress
            let waveY = baseY + amplitude * sin(x * frequency * .pi * 2)
            points.append(CGPoint(x: x, y: waveY))
        }
        
        // Create the wavy line
        path.move(to: points[0])
        for i in 1...numPoints {
            path.addLine(to: points[i])
        }
        
        platform.path = path
        platform.strokeColor = .brown
        platform.lineWidth = 2
        platform.fillColor = .clear

        // Create physics body from path
        let physicsPath = CGMutablePath()
        physicsPath.move(to: points[0])
        for i in 1...numPoints {
            physicsPath.addLine(to: points[i])
        }
        
        // Create a physics body with a small thickness
        let physicsBody = SKPhysicsBody(edgeChainFrom: physicsPath)
        platform.physicsBody = physicsBody
        platform.physicsBody?.isDynamic = false
        platform.physicsBody?.friction = 0.2
        platform.physicsBody?.restitution = 0
        platform.physicsBody?.categoryBitMask = PhysicsCategory.platform
        
        addChild(platform)
        platforms.append(platform)
        
        // Count each platform section we create
        if platform.name != "baseline" {
            totalPlatforms += 1
        }
        
        return platform
    }
    
    private func setupScore() {
        // Remove old SKLabelNode setup
    }
    
    private func updateScoreLevelLives() {
        // Remove existing nodes
        children.filter { $0.name == "scoreNode" || $0.name == "levelNode" || $0.name == "livesNode" }.forEach { $0.removeFromParent() }
        
        // Draw score
        let scoreNode = drawVectorNumber(score, at: CGPoint(x: size.width * 0.1, y: size.height * 0.95))
        scoreNode.name = "scoreNode"
        addChild(scoreNode)
        
        // Draw level
        let levelNode = drawVectorNumber(currentLevel, at: CGPoint(x: size.width * 0.5, y: size.height * 0.95))
        levelNode.name = "levelNode"
        addChild(levelNode)
        
        // Draw lives
        let livesNode = drawVectorNumber(lives, at: CGPoint(x: size.width * 0.9, y: size.height * 0.95))
        livesNode.name = "livesNode"
        addChild(livesNode)
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 0x31:  // Space
            if !gameStarted {
                startGame()
                return
            }
            if isPaused {
                restartGame()
            } else {
                handleJump()
            }
            
        case 123:  // Left arrow
            isMovingLeft = true
            isMovingRight = false
        case 124:  // Right arrow
            isMovingRight = true
            isMovingLeft = false
            
        default:
            break
        }
    }
    
    override func keyUp(with event: NSEvent) {
        guard let playerBody = player?.physicsBody else { return }
        
        switch event.keyCode {
        case 0x7B:  // Left arrow
            isMovingLeft = false
            if !isMovingRight {
                playerBody.velocity.dx = 0
                playerBody.linearDamping = 1.0  // Restore damping when stopping
            } else {
                // If right is still pressed, immediately switch to right movement
                playerBody.velocity.dx = moveSpeed
            }
            
        case 0x7C:  // Right arrow
            isMovingRight = false
            if !isMovingLeft {
                playerBody.velocity.dx = 0
                playerBody.linearDamping = 1.0  // Restore damping when stopping
            } else {
                // If left is still pressed, immediately switch to left movement
                playerBody.velocity.dx = -moveSpeed
            }
            
        default:
            break
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        updateScoreLevelLives()
        
        // Track descending state for landing sound
        if let playerNode = self.player,
           let velocity = playerNode.physicsBody?.velocity.dy {
            if hasJumped && velocity < 0 {
                isDescending = true
            }
        }
        
        // Count current balls and check for off-screen balls
        currentBallCount = basketballs.count
        
        // Create array to store balls that need to be removed
        var ballsToRemove: [SKShapeNode] = []
        
        // Check each ball's position
        for ball in basketballs {
            // Add some buffer to the screen bounds
            let buffer: CGFloat = 100  // Allow balls to go slightly off screen before removing
            
            // Check if ball is out of bounds
            if ball.position.y < -buffer ||  // Below screen
               ball.position.y > size.height + buffer ||  // Above screen
               ball.position.x < -buffer ||  // Left of screen
               ball.position.x > size.width + buffer {  // Right of screen
                ballsToRemove.append(ball)
            }
        }
        
        // Remove any off-screen balls
        for ball in ballsToRemove {
            removeBall(ball)
        }
        
        // If we have less than max balls, try to spawn a new one
        if currentBallCount < maxBalls {
            spawnReplacementBall()
        }
        
        // Remove any delay/pause in movement
        if isMovingLeft {
            let newX = player.position.x - moveSpeed * CGFloat(1.0/60.0)
            player.position.x = max(playerSize.width/2, newX)
        }
        
        if isMovingRight {
            let newX = player.position.x + moveSpeed * CGFloat(1.0/60.0)
            player.position.x = min(size.width - playerSize.width/2, newX)
        }
        
        // Add ring rotation update and check ALL balls every frame
        for ball in basketballs {
            if let ringContainer = ball.childNode(withName: "ringContainer") {
                // Counter-rotate the ring container to keep rings upright
                ringContainer.zRotation = -ball.zRotation
                
                // Get ring
                if let ring = ringContainer.childNode(withName: "ring") as? SKShapeNode {
                    // Convert player position to ball's coordinate space
                    let playerPosInBall = ball.convert(player.position, from: self)
                    let distanceToCenter = hypot(playerPosInBall.x, playerPosInBall.y)
                    
                    // Check if player is touching the ring
                    if distanceToCenter < 70 && distanceToCenter > 50 { // Ring collision range
                        // Check metadata instead of color
                        #if hasFeature(Embedded)
                        let isActive = ring.userData?["isActive"]?.boolValue ?? false
                        #else
                        let isActive = ring.userData?["isActive"] as? Bool ?? false
                        #endif
                        if isActive {
                            // Create explosion effect
                            createVectorExplosion(at: ball.position)
                            score += 10
                            showScorePopup(amount: 10, at: player.position, color: .green)
                            removeBall(ball)
                        }
                    }
                }
            }
        }
        
        // Check if player exists and is descending
        if let playerNode = self.player,  // Check if player exists first
           let velocity = playerNode.physicsBody?.velocity.dy {
            if velocity < 0 { // Negative velocity means descending
                // Retract legs if they exist
                if let leftLeg = playerNode.childNode(withName: "leftLeg"),
                   let rightLeg = playerNode.childNode(withName: "rightLeg") {
                    
                    // Only animate if legs aren't already retracting
                    if leftLeg.hasActions() == false {
                        // Retract animation
                        let retractAction = SKAction.group([
                            SKAction.scale(to: 0.5, duration: 0.2),
                            SKAction.rotate(toAngle: 0, duration: 0.2)
                        ])
                        
                        leftLeg.run(retractAction)
                        rightLeg.run(retractAction)
                    }
                }
            }
        }
        
        // Check for expired balls
        let currentTime = Date().timeIntervalSinceReferenceDate
        var expiredBalls: [SKShapeNode] = []
        
        for (ball, creationTime) in ballCreationTimes {
            if currentTime - creationTime >= ballLifespan {
                expiredBalls.append(ball)
            }
        }
        
        // Handle expired balls
        for ball in expiredBalls {
            // Create rainbow balloon effect
            createRainbowBalloon(at: ball.position)
            
            // Remove the original ball
            ballCreationTimes.removeValue(forKey: ball)
            removeBall(ball)
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        // Get the platform and player from the collision
        let platform = [contact.bodyA.node, contact.bodyB.node].first { node in
            node?.physicsBody?.categoryBitMask == PhysicsCategory.platform
        } as? SKShapeNode
        
        let playerNode = [contact.bodyA.node, contact.bodyB.node].first { node in
            node?.physicsBody?.categoryBitMask == PhysicsCategory.player
        }
        
        // Handle platform color changes
        if let platform = platform, let _ = playerNode as? SKNode {
            // Get contact normal
            let normal = contact.contactNormal
            
            // Initialize platform metadata if it doesn't exist
            if platform.userData == nil {
                platform.userData = NSMutableDictionary()
                #if hasFeature(Embedded)
                platform.userData?["state"] = .string("brown")  // Initial state
                platform.userData?["scored"] = .bool(false)
                #else
                platform.userData?["state"] = "brown"  // Initial state
                platform.userData?["scored"] = false
                #endif
            }

            // Get the current state
            #if hasFeature(Embedded)
            let currentState = platform.userData?["state"]?.stringValue ?? "brown"
            #else
            let currentState = platform.userData?["state"] as? String ?? "brown"
            #endif

            // FIXED: When hitting from above (negative normal.dy), turn GREEN
            if normal.dy > 0  {  // Hit from above
                            platform.strokeColor = .green
                    platform.fillColor = .clear
                    platform.lineWidth = 2
                #if hasFeature(Embedded)
                platform.userData?["state"] = .string("green")
                let alreadyScored = platform.userData?["scored"]?.boolValue == true
                #else
                platform.userData?["state"] = "green"
                let alreadyScored = platform.userData?["scored"] as? Bool == true
                #endif
                if !alreadyScored {
                    #if hasFeature(Embedded)
                    platform.userData?["scored"] = .bool(true)
                    #else
                    platform.userData?["scored"] = true
                    #endif
                    score += 10
                            showScorePopup(amount: 10, at: contact.contactPoint, color: .green)
                    checkLevelCompletion()
                }
                playSound("platformGreen")
            }

            // FIXED: When hitting from below (positive normal.dy), turn YELLOW
            if normal.dy < 0 && currentState == "brown" {  // Hit from below
                platform.strokeColor = .yellow
                platform.fillColor = .clear
                            platform.lineWidth = 2
                #if hasFeature(Embedded)
                platform.userData?["state"] = .string("yellow")
                #else
                platform.userData?["state"] = "yellow"
                #endif
                            
                            score += 5
                showScorePopup(amount: 5, at: contact.contactPoint, color: .yellow)
                playSound("platformYellow")
                            
                            // Check for balls on this platform
                var ballsToRemove: [SKShapeNode] = []
                            for ball in basketballs {
                                if let ballPhysics = ball.physicsBody,
                       let platformPhysics = platform.physicsBody {
                        let contactBodies = ballPhysics.allContactedBodies()
                        if contactBodies.contains(where: { $0 === platformPhysics }) {
                            createVectorImplosion(at: ball.position)
                            score += 7
                            showScorePopup(amount: 7, at: ball.position, color: .orange)
                            ballsToRemove.append(ball)
                        }
                    }
                }
                
                // Remove all affected balls
                for ball in ballsToRemove {
                    removeBall(ball)
                }
            }
        }
        
        // Check for player and ball collision, or player touching a death zone
        if collision == (PhysicsCategory.player | PhysicsCategory.obstacle) ||
           collision == (PhysicsCategory.player | PhysicsCategory.deathZone) {
            playSound("death")
            
            // Decrease life
            lives -= 1
            
            // Update lives display immediately
            updateScoreLevelLives()
            
            // Create death animation
            createDeathAnimation()
            
            // Wait for death animation to complete before respawning
            let respawnDelay = SKAction.wait(forDuration: 0.7)
            let respawnAction = SKAction.run { [self] in
                // Check for game over
                if lives <= 0 {
                    gameOver()
                } else {
                    setupPlayer()  // Only respawn if still have lives
                }
            }
            
            run(SKAction.sequence([respawnDelay, respawnAction]))
        }
        
        // Check for ground contact to enable jumping
        if collision == (PhysicsCategory.player | PhysicsCategory.ground) ||
           collision == (PhysicsCategory.player | PhysicsCategory.platform) ||
           collision == (PhysicsCategory.player | PhysicsCategory.baseline) {
            print("Ground contact detected")
            canJump = true
            
            // Only play landing sound if we were actually jumping and descending
            if hasJumped && isDescending {
                playSound("land")
                hasJumped = false  // Reset jump state
                isDescending = false  // Reset descending state
            }
            
            // Handle landing animation
            if let player = playerNode as? SKNode,
               let leftLeg = player.childNode(withName: "leftLeg"),
               let rightLeg = player.childNode(withName: "rightLeg") {
                
                // Kill any existing animations
                leftLeg.removeAllActions()
                rightLeg.removeAllActions()
                
                // Simple landing sequence with shorter legs (0.5 scale)
                let landSequence = SKAction.sequence([
                    // 1. Quick spread with short legs (0.5 scale)
                        SKAction.run {
                        // Scale to half size for landing
                        leftLeg.run(SKAction.scale(to: 0.5, duration: 0.1))
                        rightLeg.run(SKAction.scale(to: 0.5, duration: 0.1))
                        // Spread legs slightly
                        leftLeg.run(SKAction.rotate(toAngle: -.pi/4, duration: 0.1))
                        rightLeg.run(SKAction.rotate(toAngle: .pi/4, duration: 0.1))
                    },
                    
                    SKAction.wait(forDuration: 0.1),
                    
                    // 2. Remove legs
                    SKAction.run {
                        leftLeg.removeFromParent()
                        rightLeg.removeFromParent()
                    }
                ])
                
                leftLeg.run(landSequence)
                rightLeg.run(landSequence)
            }
        }
        
        // Check for rainbow balloon collision
        if contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask == (PhysicsCategory.player | PhysicsCategory.rainbow) {
            let rainbowNode = (contact.bodyA.categoryBitMask == PhysicsCategory.rainbow) ? contact.bodyA.node : contact.bodyB.node
            
            if let balloon = rainbowNode as? SKShapeNode {
                // Only process if it's the balloon (not the string)
                if balloon.name == "rainbowBalloon" {
                    if !hasExtraLifeForLevel && lives < 6 {
                        // First rainbow balloon touch this level and under 6 lives (100 points)
                        score += 100
                        lives += 1
                        hasExtraLifeForLevel = true
                        showScorePopup(amount: 100, at: balloon.position, color: .green)
                        
                        // Create large rainbow fireworks effect
                        createRainbowFireworks(at: balloon.position)
                    } else {
                        // Subsequent touches or already at max lives (50 points)
                        score += 50
                        showScorePopup(amount: 50, at: balloon.position, color: .green)
                    
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        // Create shimmer effect
                        createShimmerEffect(at: balloon.position)
                    }
                    
                    playSound("score")
                    balloon.removeFromParent()
                }
            }
        }

        // Check for ball hitting kill line
        if collision == (PhysicsCategory.killLine | PhysicsCategory.obstacle) {
            let ball = (contact.bodyA.categoryBitMask == PhysicsCategory.obstacle) ? contact.bodyA.node : contact.bodyB.node
            if let ballNode = ball as? SKShapeNode {
                removeBall(ballNode)
            }
        }

        // Check for ball hitting baseline
        if collision == (PhysicsCategory.baseline | PhysicsCategory.obstacle) {
            let ball = (contact.bodyA.categoryBitMask == PhysicsCategory.obstacle) ? contact.bodyA.node : contact.bodyB.node
            if let ballNode = ball as? SKShapeNode {
                // Remove all actions
                ballNode.removeAllActions()
                createBaselineFireworks(at: ballNode.position)
                removeBall(ballNode)
            }
        }

        // Handle player-ball collision
        if collision == (PhysicsCategory.player | PhysicsCategory.obstacle) {
            let ball = (contact.bodyA.categoryBitMask == PhysicsCategory.obstacle) ? contact.bodyA.node : contact.bodyB.node
            if let ballNode = ball as? SKShapeNode {
                // Remove all actions
                ballNode.removeAllActions()
                createBaselineFireworks(at: ballNode.position)
                removeBall(ballNode)
                
                // Award 1 point
                score += 1
                showScorePopup(amount: 1, at: contact.contactPoint, color: .orange)
                return  // Return early to prevent death handling
            }
        }
    }

    private func createBaselineFireworks(at position: CGPoint) {
        let numParticles = 30
        let colors: [NSColor] = [.yellow, .orange]
        
        // Create initial explosion
        for _ in 0..<numParticles {
            let spark = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: 2, y: 0))  // Small line for spark
            
            spark.path = path
            spark.strokeColor = colors.randomElement() ?? .yellow
            spark.position = position
            spark.lineWidth = 2
            addChild(spark)
            
            // Random angle and distance
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 50...150)
            
            // Create curved path for natural firework effect
            let duration = TimeInterval.random(in: 0.3...0.8)
            let moveAction = SKAction.customAction(withDuration: duration) { node, time in
                let progress = time / CGFloat(duration)
                let currentDistance = distance * progress
                let yOffset = 100 * sin(progress * .pi)  // Arcing motion
                
                node.position = CGPoint(
                    x: position.x + cos(angle) * currentDistance,
                    y: position.y + sin(angle) * currentDistance + yOffset
                )
            }
            
            let fadeAction = SKAction.sequence([
                SKAction.wait(forDuration: duration * 0.7),
                SKAction.fadeOut(withDuration: duration * 0.3)
            ])
            
            let rotateAction = SKAction.rotate(byAngle: CGFloat.random(in: -2 * .pi...2 * .pi), duration: duration)
            let group = SKAction.group([moveAction, fadeAction, rotateAction])
            let remove = SKAction.removeFromParent()
            
            spark.run(SKAction.sequence([group, remove]))
        }
    }
    
    private func gameOver() {
        stopBackgroundMusic()
        
        playSound("gameOver")
        // Set alpha of all existing nodes to 0.25 except game over text
        children.forEach { node in
            if node.name != "gameOverScreen" {
                node.alpha = 0.25
            }
        }
        
        // Remove all existing balls and their spawn indicators
        children.forEach { node in
            if node.name == "ball" || node.name == "spawnLine" {
                node.removeFromParent()
            }
        }
        basketballs.removeAll()
        
        // Create GAME OVER text
        let gameOverText = createVectorText("GAME OVER", 
                                          position: CGPoint(x: frame.midX, y: frame.midY + 50),
                                          color: .red,
                                          scale: 1.0)
        
        // Calculate actual width and center it
        let gameOverX = frame.midX - (gameOverText.calculateAccumulatedFrame().width / 2)
        gameOverText.position = CGPoint(x: gameOverX, y: frame.midY + 50)
        gameOverText.name = "gameOverScreen"
        addChild(gameOverText)
        
        // Create SPACE TO START text
        let startText = createVectorText("SPACE TO START",
                                       position: CGPoint(x: frame.midX, y: frame.midY - 50),
                                       color: .white,
                                       scale: 0.5)
        
        // Calculate actual width and center it
        let startX = frame.midX - (startText.calculateAccumulatedFrame().width / 2)
        startText.position = CGPoint(x: startX, y: frame.midY - 50)
        startText.name = "gameOverScreen"
        addChild(startText)
        
        // Reset game state but keep scene
        gameStarted = false
    }
    
    private func startNewGame() {
        // Reset all nodes to full alpha
        children.forEach { node in
            node.alpha = 1.0
        }
        
        // Reset game state
        score = 0
        currentLevel = 1
        lives = 3
        
        // Remove all existing nodes except score labels
        removeAllChildren()
        setupScore()
        
        // Setup initial game elements
        setupLevel()
    }
    
    // Add new function to create a single basketball
    private func createBasketball() -> SKShapeNode {
        // Don't create balls if game is over
        guard gameStarted else { return SKShapeNode() }  // Return empty node if game over
        
        // Create the ball first
        let ball = SKShapeNode(circleOfRadius: 12)
        ball.fillColor = .clear  // No fill
        ball.strokeColor = .orange  // Orange outline
        ball.lineWidth = 2  // 1-pixel outline
        ball.name = "ball"
        
        // Physics for ball - Updated collision settings
        let physicsBody = SKPhysicsBody(circleOfRadius: 12)
        physicsBody.categoryBitMask = PhysicsCategory.obstacle
        physicsBody.collisionBitMask = PhysicsCategory.platform | PhysicsCategory.baseline | PhysicsCategory.obstacle  // Added obstacle to allow ball-ball collisions
        physicsBody.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.platform
        physicsBody.restitution = 0.5
        physicsBody.friction = 0.2
        physicsBody.allowsRotation = true
        physicsBody.linearDamping = 0.1
        physicsBody.isDynamic = true
        physicsBody.affectedByGravity = true
        ball.physicsBody = physicsBody
        
        // Create ring container that won't rotate
        let ringContainer = SKNode()
        ringContainer.name = "ringContainer"
        ball.addChild(ringContainer)
        
        // Create ring and set initial color
        let ring = SKShapeNode(path: {
            let path = CGMutablePath()
            path.addArc(center: CGPoint.zero,
                       radius: 55,
                       startAngle: 0,
                       endAngle: 2 * .pi,
                       clockwise: true)
            return path
        }())
        ring.strokeColor = .white
        ring.lineWidth = 2
        ring.name = "ring"
        ring.userData = NSMutableDictionary()
        ring.userData?["isActive"] = true  // Track if ring can be interacted with
        ringContainer.addChild(ring)
        
        // Create the color alternating sequence with metadata
        let toRed = SKAction.run { 
            ring.strokeColor = .red
            ring.userData?["isActive"] = false
        }
        let toWhite = SKAction.run { 
            ring.strokeColor = .white
            ring.userData?["isActive"] = true
        }
        let waitRed = SKAction.wait(forDuration: 2.0)
        let waitWhite = SKAction.wait(forDuration: 2.0)
        
        let pulseSequence = SKAction.sequence([
            toRed,
            waitRed,
            toWhite,
            waitWhite
        ])
        
        // Run the sequence forever
        ring.run(SKAction.repeatForever(pulseSequence))
        
        // Initialize ring state
        ball.userData = ["ringTouched": false]
        
        // Add creation timestamp
        ballCreationTimes[ball] = Date().timeIntervalSinceReferenceDate
        
        return ball
    }
    
    // Add restart function
    private func restartGame() {
        
        for i in children.indices {
            let node = children[i]
            node.alpha = 1.0
        }
        
        // Remove game over label
        children.filter { $0.name == "gameOverLabel" }.forEach { $0.removeFromParent() }
        
        // Reset score and lives
        score = 0
        lives = 5

        
        // Reset to level 1
        currentLevel = 1
        
        // Use common setup for level
        setupLevel()
        
        // Unpause the game
        isPaused = false
    }
    
    // Add new function for level progression
    private func startNextLevel() {
        // Remove ALL existing nodes except score labels and player
        children.forEach { node in
            if node !== scoreLabel &&
               node !== livesLabel &&
               node !== levelLabel &&
               node !== player {  // Preserve player
                node.removeAllActions()
                node.removeFromParent()
            }
        }
        
        // Clear all arrays and tracking
        platforms.removeAll()
        basketballs.removeAll()
        scoredPlatforms.removeAll()
        recentSpawnLocations.removeAll()
        ballCreationTimes.removeAll()
        
        // Reset counters and state
        currentBallCount = 0
        totalPlatforms = 0
        hasExtraLifeForLevel = false
        isSpawningBall = false
        baselineScored = false
        
        // Increment level
        currentLevel += 1
        
        // Show level complete message
        playSound("levelComplete")
        let levelComplete = SKLabelNode(text: "Level Complete!")
    
        
        
        
        
        
        
        
        
        levelComplete.position = CGPoint(x: size.width/2, y: size.height/2)
        levelComplete.fontName = "Courier"
        levelComplete.fontSize = 36
        levelComplete.fontColor = .green
        addChild(levelComplete)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        let wait = SKAction.wait(forDuration: 1.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        let setupNew = SKAction.run { [self] in
            setupLevel()  // Setup new level after animation
        }
        
        levelComplete.run(SKAction.sequence([fadeIn, wait, fadeOut, remove, setupNew]))
    }
    
    private func handleJump() {
        if canJump {
            hasJumped = true
            isDescending = false
            playSound("jump")
            print("Attempting jump")
            player.physicsBody?.velocity.dy = 0
            
            // Create and show legs for jump if they don't exist
            let leftLeg = player.childNode(withName: "leftLeg") ?? createLShapedLeg(pixelSize: 5, isLeft: true)
            let rightLeg = player.childNode(withName: "rightLeg") ?? createLShapedLeg(pixelSize: 5, isLeft: false)
            
            if leftLeg.parent == nil { player.addChild(leftLeg) }
            if rightLeg.parent == nil { player.addChild(rightLeg) }
        
            // Simple vector-style jump animation
            let jumpSequence = SKAction.sequence([
                // 1. Start with short legs
                SKAction.run {
                    // Scale legs to 0.5 their size initially
                    leftLeg.setScale(0.5)
                    rightLeg.setScale(0.5)
                    // Quick crouch with short legs
                    leftLeg.run(SKAction.rotate(toAngle: -.pi/4, duration: 0.1))
                    rightLeg.run(SKAction.rotate(toAngle: .pi/4, duration: 0.1))
                },
                
                SKAction.wait(forDuration: 0.1),
                
                // 2. Explosive extension with full-size legs
                SKAction.run {
                    // Scale to full size during extension
                    leftLeg.run(SKAction.scale(to: 1.0, duration: 0.05))
                    rightLeg.run(SKAction.scale(to: 1.0, duration: 0.05))
                    leftLeg.run(SKAction.rotate(toAngle: .pi/6, duration: 0.05))
                    rightLeg.run(SKAction.rotate(toAngle: -.pi/6, duration: 0.05))
                }
            ])
            
            leftLeg.run(jumpSequence)
            rightLeg.run(jumpSequence)
            
            // Apply jump forces
            if isMovingLeft || isMovingRight {
                // Running jump
                player.physicsBody?.applyImpulse(CGVector(
                    dx: isMovingLeft ? -JumpForce.runningHorizontal : JumpForce.runningHorizontal,
                    dy: JumpForce.runningVertical
                ))
            } else {
                // Standing jump
                player.physicsBody?.applyImpulse(CGVector(
                    dx: JumpForce.standingHorizontal,
                    dy: JumpForce.standingVertical
                ))
            }
            
            // Create and extend legs
            createLShapedLeg(pixelSize: playerSize.width, isLeft: true)
            createLShapedLeg(pixelSize: playerSize.width, isLeft: false)
            
            // Reset leg size and rotation
            if let leftLeg = player.childNode(withName: "leftLeg"),
               let rightLeg = player.childNode(withName: "rightLeg") {
                leftLeg.setScale(1.0)
                rightLeg.setScale(1.0)
                leftLeg.zRotation = 0
                rightLeg.zRotation = 0
            }
            
            canJump = false
        }
    }
    
    private func setupPlayer() {
        // Create main container node
        player = SKShapeNode()
        player.name = "player"
        // Vector-style bullfrog head outline
        let headOutline = SKShapeNode()
        let headPath = CGMutablePath()
        let headWidth: CGFloat = 25
        let headHeight: CGFloat = 35  // Keeping original height
        
        // Create bullfrog head shape with rounded top and bottom
        let points: [CGPoint] = [
            CGPoint(x: -headWidth/2, y: -headHeight/3),      // Left bottom curve start
            CGPoint(x: -headWidth/1.8, y: 0),                // Left middle bulge
            CGPoint(x: -headWidth/2, y: headHeight/4),       // Left upper indent
            CGPoint(x: -headWidth/3, y: headHeight/2),       // Left upper curve
            CGPoint(x: 0, y: headHeight/1.8),                // Top middle
            CGPoint(x: headWidth/3, y: headHeight/2),        // Right upper curve
            CGPoint(x: headWidth/2, y: headHeight/4),        // Right upper indent
            CGPoint(x: headWidth/1.8, y: 0),                 // Right middle bulge
            CGPoint(x: headWidth/2, y: -headHeight/3)        // Right bottom curve start
        ]
        
        // Draw head outline with curved bottom and top
        headPath.move(to: points[0])
        
        // Draw left side up to the start of top curve
        for i in 1...3 {
            headPath.addLine(to: points[i])
        }
        
        // Draw curved top
        let topControlPoint = CGPoint(x: 0, y: headHeight/1.7 + 2)
        headPath.addQuadCurve(to: points[5], control: topControlPoint)

        // Draw right side down
        for i in 6..<points.count {
            headPath.addLine(to: points[i])
        }

        // Add curved bottom
        let bottomControlPoint = CGPoint(x: 0, y: -headHeight/2 - 2)
        headPath.addQuadCurve(to: points[0], control: bottomControlPoint)

        headOutline.path = headPath
        headOutline.strokeColor = .green
        headOutline.lineWidth = 2
        headOutline.fillColor = .clear
        player.addChild(headOutline)
        
        // Vector-style eyes (larger stop sign shaped)
        let eyeSize: CGFloat = 10  // Increased from 8 to 10
        let eyeY = headHeight/5    // Adjusted position for bullfrog face
        
        // Function to create stop sign shaped eye
        func createStopSignEye(isLeft: Bool) -> SKShapeNode {
            let eye = SKShapeNode()
            let eyePath = CGMutablePath()
            let center = CGPoint(x: isLeft ? -headWidth/3 : headWidth/3, y: eyeY)
            let numSides = 8
            
            // Create octagon points
            for i in 0..<numSides {
                let angle = CGFloat(i) * .pi * 2 / CGFloat(numSides) - .pi/8 // Rotate by -22.5 degrees
                let point = CGPoint(
                    x: center.x + cos(angle) * eyeSize/2,
                    y: center.y + sin(angle) * eyeSize/2
                )
                
                if i == 0 {
                    eyePath.move(to: point)
                } else {
                    eyePath.addLine(to: point)
                }
            }
            eyePath.closeSubpath()
            
            eye.path = eyePath
            eye.strokeColor = .white
            eye.lineWidth = 2
            eye.fillColor = .clear
            return eye
        }
        
        // Create and add eyes
        let leftEye = createStopSignEye(isLeft: true)
        let rightEye = createStopSignEye(isLeft: false)
        player.addChild(leftEye)
        player.addChild(rightEye)

        // Keep existing smile but adjust position higher
        let expression = SKShapeNode()
        let expressionPath = CGMutablePath()
        let mouthWidth: CGFloat = headWidth/2
        let mouthY = -headHeight/4 + 3  // Moved up 3 pixels

        expressionPath.move(to: CGPoint(x: -mouthWidth/2, y: mouthY))
        expressionPath.addQuadCurve(
            to: CGPoint(x: mouthWidth/2, y: mouthY),
            control: CGPoint(x: 0, y: mouthY - 5)
        )

        expression.path = expressionPath
        expression.strokeColor = .white
        expression.lineWidth = 2
        player.addChild(expression)

        // Physics setup - use the same path as the head outline for physics
        player.physicsBody = SKPhysicsBody(polygonFrom: headPath)  // Use the same path we drew
        player.physicsBody?.isDynamic = true
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.restitution = 0.0
        player.physicsBody?.friction = 0.2
        player.physicsBody?.mass = 1.0
        player.physicsBody?.linearDamping = 1.0
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.collisionBitMask = PhysicsCategory.platform | PhysicsCategory.baseline | PhysicsCategory.ground
        player.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.ground | 
                                                PhysicsCategory.platform | PhysicsCategory.baseline
        
        // Position player higher above baseline
        player.position = CGPoint(x: size.width * 0.05,
                                y: baselineHeight + playerSize.height)  // Added full height instead of half
        addChild(player)
    }
    
    @discardableResult
    private func createLShapedLeg(pixelSize: CGFloat, isLeft: Bool) -> SKShapeNode {
        let leg = SKShapeNode()
        leg.name = isLeft ? "leftLeg" : "rightLeg"
        
        // Create thigh outline - longer for better frog proportions
        let thigh = SKShapeNode()
        let thighPath = CGMutablePath()
        let thighLength: CGFloat = 20  // Increased length
        
        // Thigh outline points
        thighPath.move(to: CGPoint(x: 0, y: 0))
        thighPath.addLine(to: CGPoint(x: 0, y: -thighLength))
        
        thigh.path = thighPath
        thigh.strokeColor = .green  // Changed to green
        thigh.lineWidth = 2
        thigh.name = "thigh"
        leg.addChild(thigh)
        
        // Create knee joint - slightly larger for better visibility
        let knee = SKShapeNode(circleOfRadius: 4)
        knee.strokeColor = .green  // Changed to green
        knee.lineWidth = 2
        knee.fillColor = .clear
        knee.position = CGPoint(x: 0, y: -thighLength)
        knee.name = "knee"
        leg.addChild(knee)
        
        // Create calf outline - longer and more angled for frog-like appearance
        let calf = SKShapeNode()
        let calfPath = CGMutablePath()
        let calfLength: CGFloat = 25  // Increased length
        let calfOffset: CGFloat = isLeft ? -12 : 12  // Increased angle
        
        // Calf outline points
        calfPath.move(to: CGPoint(x: 0, y: 0))
        calfPath.addLine(to: CGPoint(x: calfOffset, y: -calfLength))
        
        calf.path = calfPath
        calf.strokeColor = .green  // Changed to green
        calf.lineWidth = 2
        calf.position = CGPoint(x: 0, y: -thighLength)
        calf.name = "calf"
        leg.addChild(calf)
        
        // Create foot outline - wider for better traction
        let foot = SKShapeNode()
        let footPath = CGMutablePath()
        let footLength: CGFloat = 15  // Increased length
        
        // Foot outline points with slight curve for better traction
        
        
        
        
        
        footPath.move(to: CGPoint(x: 0, y: 0))
        let footCurve = isLeft ? -footLength : footLength
        footPath.addCurve(to: CGPoint(x: footCurve, y: 0),
                         control1: CGPoint(x: footCurve/2, y: -2),
                         control2: CGPoint(x: footCurve/2, y: -2))
        
        foot.path = footPath
        foot.strokeColor = .green  // Changed to green
        foot.lineWidth = 2
        foot.position = CGPoint(x: calfOffset, y: -thighLength - calfLength)
        foot.name = "foot"
        leg.addChild(foot)
        
        // Position the entire leg - adjusted for better placement
        leg.position = CGPoint(x: isLeft ? -pixelSize * 2.5 : pixelSize * 2.5, y: -pixelSize * 2)
        
        return leg
    }
    
    // Helper function to show score popup
    private func showScorePopup(amount: Int, at position: CGPoint, color: NSColor) {
        playSound("score")
        // Create vector number for the score popup
        let scorePopup = drawVectorNumber(amount, at: position, isRainbow: amount == 50 || amount == 100)  // Add rainbow parameter
        scorePopup.position = CGPoint(x: position.x, y: position.y + 20)
        addChild(scorePopup)
        
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        scorePopup.run(SKAction.sequence([SKAction.group([moveUp, fadeOut]), remove]))
    }
    
    private func drawVectorNumber(_ number: Int, at position: CGPoint, isRainbow: Bool = false) -> SKNode {
        let numberNode = SKNode()
        let digitWidth: CGFloat = 10
        let digitSpacing: CGFloat = 5  // Add spacing between digits
        let digitHeight: CGFloat = 20
        
        let digitPoints: [[CGPoint]] = [
            // 0
            [CGPoint(x: 0, y: 0), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: 0)],
            // 1
            [CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight)],
            // 2
            [CGPoint(x: 0, y: digitHeight), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: digitWidth, y: digitHeight/2),
             CGPoint(x: digitWidth, y: digitHeight/2), CGPoint(x: 0, y: digitHeight/2),
             CGPoint(x: 0, y: digitHeight/2), CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 0), CGPoint(x: digitWidth, y: 0)],
            // 3 - Fixed pattern
            [CGPoint(x: 0, y: digitHeight), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: digitHeight/2), CGPoint(x: digitWidth, y: digitHeight/2)],
            // 4
            [CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: digitHeight / 2),
             CGPoint(x: 0, y: digitHeight / 2), CGPoint(x: digitWidth, y: digitHeight / 2),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: digitWidth, y: 0)],
            // 5
            [CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: digitHeight / 2),
             CGPoint(x: 0, y: digitHeight / 2), CGPoint(x: digitWidth, y: digitHeight / 2),
             CGPoint(x: digitWidth, y: digitHeight / 2), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: 0, y: 0)],
            // 6
            [CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: 0), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight / 2),
             CGPoint(x: digitWidth, y: digitHeight / 2), CGPoint(x: 0, y: digitHeight / 2)],
            // 7
            [CGPoint(x: 0, y: digitHeight), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: digitWidth, y: 0)],
            // 8
            [CGPoint(x: 0, y: 0), CGPoint(x: digitWidth, y: 0),
             CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: 0),
             CGPoint(x: 0, y: digitHeight / 2), CGPoint(x: digitWidth, y: digitHeight / 2)],
            // 9
            [CGPoint(x: digitWidth, y: 0), CGPoint(x: digitWidth, y: digitHeight),
             CGPoint(x: digitWidth, y: digitHeight), CGPoint(x: 0, y: digitHeight),
             CGPoint(x: 0, y: digitHeight), CGPoint(x: 0, y: digitHeight / 2),
             CGPoint(x: 0, y: digitHeight / 2), CGPoint(x: digitWidth, y: digitHeight / 2)]
        ]
        
        // Convert number to string to process each digit
        let digits = String(number).compactMap { Int(String($0)) }
        var totalWidth: CGFloat = 0  // Track total width for centering
        
        // First calculate total width
        totalWidth = CGFloat(digits.count) * (digitWidth + digitSpacing) - digitSpacing
        
        // Start drawing from the left, accounting for total width
        var currentX: CGFloat = -totalWidth / 2  // Center the entire number
        
        for (index, digit) in digits.enumerated() {
            let digitNode = SKNode()
            
            for i in stride(from: 0, to: digitPoints[digit].count, by: 2) {
                let line = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: digitPoints[digit][i])
                path.addLine(to: digitPoints[digit][i + 1])
                line.path = path
                
                if isRainbow {
                    // Calculate hue based on both digit position and line position
                    let hue = (CGFloat(index) + CGFloat(i) / CGFloat(digitPoints[digit].count)) / CGFloat(digits.count)
                    line.strokeColor = NSColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
                } else {
                line.strokeColor = .green
                }
                
                line.lineWidth = 2
                digitNode.addChild(line)
            }
            
            // Position each digit with proper spacing
            digitNode.position = CGPoint(x: currentX, y: 0)
            numberNode.addChild(digitNode)
            
            // Move to next digit position
            currentX += digitWidth + digitSpacing
        }
        
        numberNode.position = position
        return numberNode
    }
    
    // Add this new function for the vector explosion effect
    private func createVectorExplosion(at position: CGPoint) {
        playSound("ballCollect")
        let numLines = 12
        let explosionRadius: CGFloat = 50
        
        for i in 0..<numLines {
            let angle = (CGFloat(i) / CGFloat(numLines)) * CGFloat.pi * 2
            
            // Create line
            let line = SKShapeNode()
            let path = CGMutablePath()
            
            // Start at explosion center
            path.move(to: .zero)
            
            // End point based on angle
            let endPoint = CGPoint(
                x: cos(angle) * explosionRadius,
                y: sin(angle) * explosionRadius
            )
            path.addLine(to: endPoint)
            
            line.path = path
            line.strokeColor = .white
            line.lineWidth = 2
            line.position = position
            
            // Add to scene
            addChild(line)
            
            // Animate
            let moveAction = SKAction.scale(by: 1.5, duration: 0.3)
            let fadeAction = SKAction.fadeOut(withDuration: 0.3)
            let group = SKAction.group([moveAction, fadeAction])
            let remove = SKAction.removeFromParent()
            
            line.run(SKAction.sequence([group, remove]))
        }
    }
    
    // Add this new function for the implosion effect
    private func createVectorImplosion(at position: CGPoint) {
        playSound("ballImplosion")
        let numLines = 12
        let startRadius: CGFloat = 50
        
        for i in 0..<numLines {
            let angle = (CGFloat(i) / CGFloat(numLines)) * CGFloat.pi * 2
            
            // Create line
            let line = SKShapeNode()
            let path = CGMutablePath()
            
            // Start at outer position
            let startPoint = CGPoint(
                x: cos(angle) * startRadius,
                y: sin(angle) * startRadius
            )
            path.move(to: startPoint)
            
            // End at center
            path.addLine(to: .zero)
            
            line.path = path
            line.strokeColor = .orange
            line.lineWidth = 2
            line.position = position
            
            // Add to scene
            addChild(line)
            
            // Animate
            let scaleAction = SKAction.scale(to: 0.1, duration: 0.3)
            let fadeAction = SKAction.fadeOut(withDuration: 0.3)
            let group = SKAction.group([scaleAction, fadeAction])
            let remove = SKAction.removeFromParent()
            
            line.run(SKAction.sequence([group, remove]))
        }
    }
    
    // Add this function to check for level completion
    private func checkLevelCompletion() {
        // Get all platforms in the scene
        let platforms = children.filter { node in
            node.physicsBody?.categoryBitMask == PhysicsCategory.platform
        }
        
        // Check if all platforms are green. Two guards, both needed:
        // - !platforms.isEmpty: allSatisfy is vacuously true on an empty array.
        // - platforms.count >= totalPlatforms: re-deriving the platform set
        //   from `children` can catch a moment mid-transition where only a
        //   handful of (fresh, already-green-by-coincidence) platforms exist
        //   yet, between the old level being cleared and the new one fully
        //   built — a false "all green" there re-triggers startNextLevel(),
        //   which cascades into a rapid clear/rebuild loop (wiping the
        //   baseline/death zones along with everything else, repeatedly).
        let allGreen = !platforms.isEmpty && platforms.count >= totalPlatforms && platforms.allSatisfy { platform in
            if let platform = platform as? SKShapeNode {
                return platform.strokeColor == .green
            }
            return false
        }
        
        // If all platforms are green, complete the level
        if allGreen {
            startNextLevel()
            setupLevel()  // Setup next level
        }
    }
    
    private func createDeathAnimation() {
        // Store all the lines that make up the frog's head
        var headLines: [SKShapeNode] = []
        
        // Get head outline points
        let headWidth: CGFloat = 25
        let headHeight: CGFloat = 35
        
        // Create bullfrog head points (same as setup)
        let points: [CGPoint] = [
            CGPoint(x: -headWidth/2, y: -headHeight/3),      // Left bottom curve start
            CGPoint(x: -headWidth/1.8, y: 0),                // Left middle bulge
            CGPoint(x: -headWidth/2, y: headHeight/4),       // Left upper indent
            CGPoint(x: -headWidth/3, y: headHeight/2),       // Left upper curve
            CGPoint(x: 0, y: headHeight/1.8),                // Top middle
            CGPoint(x: headWidth/3, y: headHeight/2),        // Right upper curve
            CGPoint(x: headWidth/2, y: headHeight/4),        // Right upper indent
            CGPoint(x: headWidth/1.8, y: 0),                 // Right middle bulge
            CGPoint(x: headWidth/2, y: -headHeight/3)        // Right bottom curve start
        ]
        
        // Create individual lines for each segment
        for i in 0..<points.count-1 {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: points[i])
            path.addLine(to: points[i + 1])
            line.path = path
            line.strokeColor = .green
            line.lineWidth = 2
            line.position = player.position
            addChild(line)
            headLines.append(line)
        }
        
        // Add curved bottom as a single line
        let bottomLine = SKShapeNode()
        let bottomPath = CGMutablePath()
        bottomPath.move(to: points.last!)
        let bottomControlPoint = CGPoint(x: 0, y: -headHeight/2 - 2)
        bottomPath.addQuadCurve(to: points[0], control: bottomControlPoint)
        bottomLine.path = bottomPath
        bottomLine.strokeColor = .green
        bottomLine.lineWidth = 2
        bottomLine.position = player.position
        addChild(bottomLine)
        headLines.append(bottomLine)
        
        // Add curved top as a single line
        let topLine = SKShapeNode()
        let topPath = CGMutablePath()
        topPath.move(to: points[3])  // Left upper curve
        let topControlPoint = CGPoint(x: 0, y: headHeight/1.7 + 2)
        topPath.addQuadCurve(to: points[5], control: topControlPoint)  // To right upper curve
        topLine.path = topPath
        topLine.strokeColor = .green
        topLine.lineWidth = 2
        topLine.position = player.position
        addChild(topLine)
        headLines.append(topLine)
        
        // Create lines for larger eyes
        let eyeSize: CGFloat = 10
        let eyeY = headHeight/5
        
        // Left eye
        let leftEye = SKShapeNode(circleOfRadius: eyeSize/2)
        leftEye.strokeColor = .white
        leftEye.lineWidth = 2
        leftEye.position = CGPoint(x: player.position.x - headWidth/3, y: player.position.y + eyeY)
        addChild(leftEye)
        headLines.append(leftEye)
        
        // Right eye
        let rightEye = SKShapeNode(circleOfRadius: eyeSize/2)
        rightEye.strokeColor = .white
        rightEye.lineWidth = 2
        rightEye.position = CGPoint(x: player.position.x + headWidth/3, y: player.position.y + eyeY)
        addChild(rightEye)
        headLines.append(rightEye)
        
        // Smile (moved up 3 pixels)
        let smile = SKShapeNode()
        let smilePath = CGMutablePath()
        let mouthWidth: CGFloat = headWidth/2
        let mouthY = -headHeight/4 + 3  // Moved up 3 pixels
        smilePath.move(to: CGPoint(x: -mouthWidth/2, y: mouthY))
        smilePath.addQuadCurve(
            to: CGPoint(x: mouthWidth/2, y: mouthY),
            control: CGPoint(x: 0, y: mouthY - 5)
        )
        smile.path = smilePath
        smile.strokeColor = .white
        smile.lineWidth = 2
        smile.position = player.position
        addChild(smile)
        headLines.append(smile)
        
        // Animate each line separately
        for (index, line) in headLines.enumerated() {
            let randomAngle = CGFloat.random(in: -CGFloat.pi...CGFloat.pi)
            let randomDistance = CGFloat.random(in: 20...50)
            let movePoint = CGPoint(
                x: line.position.x + cos(randomAngle) * randomDistance,
                y: line.position.y + sin(randomAngle) * randomDistance
            )
            
            let moveAction = SKAction.move(to: movePoint, duration: 0.5)
            let fadeAction = SKAction.fadeOut(withDuration: 0.5)
            let rotateAction = SKAction.rotate(byAngle: randomAngle, duration: 0.5)
            let group = SKAction.group([moveAction, fadeAction, rotateAction])
            let remove = SKAction.removeFromParent()
            
            // Add slight delay based on index for cascade effect
            let delay = SKAction.wait(forDuration: Double(index) * 0.05)
            line.run(SKAction.sequence([delay, group, remove]))
        }
        
        // Remove the original player node
        player.removeFromParent()
    }
    
    // Fix the createVectorText function
    private func createVectorText(_ text: String, position: CGPoint, color: NSColor, scale: CGFloat = 1.0) -> SKNode {
        let textNode = SKNode()
        var offsetX: CGFloat = 0
        
        for char in text.uppercased() {
            if let points = vectorLetters[String(char)] {
                let letterNode = SKNode()
                
                // Draw lines for each pair of points
                for i in stride(from: 0, to: points.count, by: 2) {
                        let line = SKShapeNode()
                        let path = CGMutablePath()
                        
                        let startPoint = CGPoint(
                        x: points[i].x * scale,
                        y: points[i].y * scale
                        )
                        let endPoint = CGPoint(
                        x: points[i + 1].x * scale,
                        y: points[i + 1].y * scale
                        )
                        
                        path.move(to: startPoint)
                        path.addLine(to: endPoint)
                        
                        line.path = path
                        line.strokeColor = color
                        line.lineWidth = 2
                        letterNode.addChild(line)
                }
                
                letterNode.position = CGPoint(x: offsetX, y: 0)
                textNode.addChild(letterNode)
                
                offsetX += 50 * scale  // Space between letters
            }
        }
        
        textNode.position = position
        return textNode
    }
    
    // Add this function to create baseline and death zones
    private func createBaselineWithDeathZones() {
        // Create kill line 20 pixels below screen
        let killLine = SKNode()
        let killLineBody = SKPhysicsBody(edgeFrom: CGPoint(x: -50, y: -20),
                                       to: CGPoint(x: size.width + 50, y: -20))
        killLine.physicsBody = killLineBody
        killLine.physicsBody?.categoryBitMask = PhysicsCategory.killLine
        killLine.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle
        killLine.physicsBody?.collisionBitMask = 0
        addChild(killLine)

        // Create green baseline 3px up from bottom (ensures full visibility with 2px line width)
        let baseline = SKShapeNode()
        let baselinePath = CGMutablePath()
        baselinePath.move(to: CGPoint(x: 0, y: 3))  // 3px up from bottom
        baselinePath.addLine(to: CGPoint(x: size.width, y: 3))  // 3px up from bottom

        baseline.path = baselinePath
        baseline.strokeColor = .green
        baseline.lineWidth = baselineLineWidth
        baseline.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 3), to: CGPoint(x: size.width, y: 3))
        baseline.physicsBody?.categoryBitMask = PhysicsCategory.baseline
        baseline.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle
        baseline.physicsBody?.collisionBitMask = 0
        addChild(baseline)
        
        // Create 3 evenly spaced red death zones
        let totalWidth = size.width
        let usableWidth = totalWidth - (deathZoneWidth * 3)
        let spacing = usableWidth / 4
        
        for i in 0..<3 {
            let deathZone = SKShapeNode()
            let deathZonePath = CGMutablePath()

            let xPosition = spacing + (CGFloat(i) * (deathZoneWidth + spacing))
            deathZonePath.move(to: CGPoint(x: xPosition, y: 3))  // 3px up from bottom
            deathZonePath.addLine(to: CGPoint(x: xPosition + deathZoneWidth, y: 3))  // 3px up from bottom

            deathZone.path = deathZonePath
            deathZone.strokeColor = .red
            deathZone.lineWidth = baselineLineWidth
            deathZone.name = "deathZone"

            // Add physics body for death zone
            deathZone.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: xPosition, y: 3),
                                                 to: CGPoint(x: xPosition + deathZoneWidth, y: 3))
            deathZone.physicsBody?.categoryBitMask = PhysicsCategory.deathZone
            deathZone.physicsBody?.contactTestBitMask = PhysicsCategory.player
            deathZone.physicsBody?.collisionBitMask = 0

            addChild(deathZone)
        }
    }
    
    // Update ball removal to maintain accurate count
    private func removeBall(_ ball: SKShapeNode) {
        // Remove all actions from the ball and its children
        ball.removeAllActions()
        ball.children.forEach { child in
            child.removeAllActions()
            child.children.forEach { grandChild in
                grandChild.removeAllActions()
            }
        }
        
        // Remove the ball from the scene and arrays
        ball.removeFromParent()
        if let index = basketballs.firstIndex(where: { $0 === ball }) {
            basketballs.remove(at: index)
            currentBallCount -= 1
        }
        
        // Remove from creation times tracking
        ballCreationTimes.removeValue(forKey: ball)
    }
    
    // Add at top of class with other properties
    private var hasJumped = false
    private var isDescending = false
    
    // Add at top of class with other properties
    private let ballLifespan: TimeInterval = 10.0  // 10 seconds
    private var ballCreationTimes: [SKShapeNode: TimeInterval] = [:]
    
    // Add at top of class with other properties
    private var hasExtraLifeForLevel = false  // Track if player got extra life this level
    
    // Update createRainbowBalloon function
    private func createRainbowBalloon(at position: CGPoint) {
        // Create balloon circle (slightly larger than original ball)
        let balloon = SKShapeNode(circleOfRadius: 15)
        balloon.position = position
        balloon.lineWidth = 2
        balloon.name = "rainbowBalloon"
        
        // Create rainbow gradient for the stroke
        let numSegments = 36  // More segments for smoother gradient
        let radius: CGFloat = 15
        
        // Create a circle made of small line segments
        for i in 0...numSegments {
            let angle = (CGFloat(i) / CGFloat(numSegments)) * CGFloat.pi * 2
            let point = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
            
            // Create small line segment with color based on angle
            let segment = SKShapeNode()
            let segmentPath = CGMutablePath()
            let nextAngle = (CGFloat(i + 1) / CGFloat(numSegments)) * CGFloat.pi * 2
            let nextPoint = CGPoint(
                x: cos(nextAngle) * radius,
                y: sin(nextAngle) * radius
            )
            
            segmentPath.move(to: point)
            segmentPath.addLine(to: nextPoint)
            segment.path = segmentPath
            segment.lineWidth = 2
            
            // Calculate color based on position in circle
            let hue = CGFloat(i) / CGFloat(numSegments)
            segment.strokeColor = NSColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
            balloon.addChild(segment)
        }
        
        // Create string container to hold all string segments
        let stringContainer = SKNode()
        stringContainer.name = "stringContainer"
        balloon.addChild(stringContainer)
        
        // Create squiggly string with rainbow gradient
        let startY = -balloon.frame.height/2  // Start from bottom of balloon
        let amplitude: CGFloat = 5
        let frequency: CGFloat = 0.3
        let numPoints = 16
        
        // Create points for the squiggly line
        var points: [CGPoint] = []
        for i in 0..<numPoints {
            let y = startY - CGFloat(i) * 2
            let x = sin(CGFloat(i) * frequency) * amplitude
            points.append(CGPoint(x: x, y: y))
        }
        
        // Create gradient segments for the string
        for i in 0..<points.count-1 {
            let segment = SKShapeNode()
            let segmentPath = CGMutablePath()
            segmentPath.move(to: points[i])
            segmentPath.addLine(to: points[i + 1])
            segment.path = segmentPath
            segment.lineWidth = 2
            
            // Calculate color based on position in string
            let hue = CGFloat(i) / CGFloat(points.count - 1)
            segment.strokeColor = NSColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
            stringContainer.addChild(segment)  // Add to string container
        }
        
        // Add physics body for collision detection
        balloon.physicsBody = SKPhysicsBody(circleOfRadius: 15)
        balloon.physicsBody?.categoryBitMask = PhysicsCategory.rainbow
        balloon.physicsBody?.contactTestBitMask = PhysicsCategory.player
        balloon.physicsBody?.collisionBitMask = 0
        balloon.physicsBody?.isDynamic = false
        
        addChild(balloon)
        
        // Create floating animation for balloon (string will move with it since it's a child)
        let floatUp = SKAction.moveBy(x: 0, y: 150, duration: 4.0)  // Changed to 4.0 seconds
        let fade = SKAction.fadeOut(withDuration: 1.0)
        let group = SKAction.group([
            SKAction.sequence([
                SKAction.wait(forDuration: 3.0),  // Wait longer before fade (3 seconds)
                fade
            ]),
            floatUp
        ])
        let remove = SKAction.removeFromParent()
        balloon.run(SKAction.sequence([group, remove]))
    }
    
    // Add new function for rainbow fireworks
    private func createRainbowFireworks(at position: CGPoint) {
        let numParticles = 80  // Increased number of particles
        let minRadius: CGFloat = 50  // Increased minimum distance
        let maxRadius: CGFloat = 200  // Increased maximum distance
        
        // Create multiple bursts with different delays
        for burstIndex in 0...2 {  // Create 3 bursts
            let burstDelay = Double(burstIndex) * 0.1  // Stagger the bursts
            
            for i in 0..<numParticles {
                // Create longer spark line
                let spark = SKShapeNode()
                let sparkPath = CGMutablePath()
                sparkPath.move(to: .zero)
                sparkPath.addLine(to: CGPoint(x: CGFloat.random(in: 4...8), y: 0))  // Longer spark
                
                spark.path = sparkPath
                // Rainbow color based on angle
                let hue = CGFloat(i) / CGFloat(numParticles)
                spark.strokeColor = NSColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
                spark.position = position
                spark.lineWidth = CGFloat.random(in: 1...3)  // Varied line width
                spark.alpha = 0.8
                addChild(spark)
                
                let angle = CGFloat(i) * 2 * .pi / CGFloat(numParticles) + 
                           CGFloat.random(in: -0.2...0.2)  // Slight angle variation
                let distance = CGFloat.random(in: minRadius...maxRadius)
                
                let duration = TimeInterval.random(in: 0.6...1.2)  // Longer duration
                
                // Create more natural firework motion
                let moveAction = SKAction.customAction(withDuration: duration) { node, time in
                    let progress = time / CGFloat(duration)
                    let currentDistance = distance * progress
                    
                    // Add gravity effect
                    let gravity: CGFloat = -50.0
                    let yOffset = gravity * pow(progress, 2)
                    
                    // Add slight wave motion
                    let wave = sin(progress * 4 * .pi) * 5 * (1 - progress)
                    
                    node.position = CGPoint(
                        x: position.x + cos(angle) * currentDistance + wave,
                        y: position.y + sin(angle) * currentDistance + yOffset
                    )
                    
                    // Rotate spark to follow its path
                    let rotation = atan2(sin(angle) + gravity * progress, cos(angle))
                    node.zRotation = rotation
                }
                
                // Create trail effect
                let trailAction = SKAction.customAction(withDuration: duration) { node, time in
                    if time > 0.1 {  // Start trail after initial movement
                        let trail = SKShapeNode(path: sparkPath)
                        trail.strokeColor = spark.strokeColor.withAlphaComponent(0.3)
                        trail.lineWidth = spark.lineWidth * 0.5
                        trail.position = node.position
                        trail.zRotation = node.zRotation
                        self.addChild(trail)
                        
                        let fadeOut = SKAction.sequence([
                            SKAction.fadeOut(withDuration: 0.1),
                            SKAction.removeFromParent()
                        ])
                        trail.run(fadeOut)
                    }
                }
                
                let fadeAction = SKAction.sequence([
                    SKAction.wait(forDuration: duration * 0.7),
                    SKAction.fadeOut(withDuration: duration * 0.3)
                ])
                
                let group = SKAction.group([moveAction, fadeAction, trailAction])
                let remove = SKAction.removeFromParent()
                
                // Add delay for burst effect
                let delay = SKAction.wait(forDuration: burstDelay)
                spark.run(SKAction.sequence([delay, group, remove]))
            }
        }
        
        // Add central flash
        let flash = SKShapeNode(circleOfRadius: 15)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.position = position
        flash.alpha = 0.9
        addChild(flash)
        
        let flashFade = SKAction.fadeOut(withDuration: 0.2)
        let removeFlash = SKAction.removeFromParent()
        flash.run(SKAction.sequence([flashFade, removeFlash]))
    }
    
    // Add new function for shimmer effect
    private func createShimmerEffect(at position: CGPoint) {
        let numParticles = 40  // Increased particles
        let colors: [NSColor] = (0..<8).map { i in
            NSColor(hue: CGFloat(i) / 8.0, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        }
        
        // Create multiple pops with different delays
        for popIndex in 0...2 {  // Create 3 pops
            let popDelay = Double(popIndex) * 0.1
            
            for _ in 0..<numParticles {
                let spark = SKShapeNode()
                let sparkPath = CGMutablePath()
                sparkPath.move(to: .zero)
                sparkPath.addLine(to: CGPoint(x: CGFloat.random(in: 3...6), y: 0))  // Spark line
                
                spark.path = sparkPath
                spark.strokeColor = colors.randomElement() ?? .white
                spark.position = position
                spark.lineWidth = CGFloat.random(in: 1...2)
                spark.alpha = 0.8
                addChild(spark)
                
                // Random angle and distance
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 30...80)
                
                let duration = TimeInterval.random(in: 0.3...0.6)
                
                // Create popping motion
                let moveAction = SKAction.customAction(withDuration: duration) { node, time in
                    let progress = time / CGFloat(duration)
                    let currentDistance = distance * progress
                    
                    // Add arcing motion
                    let yOffset = 50 * sin(progress * .pi)
                    
                    node.position = CGPoint(
                        x: position.x + cos(angle) * currentDistance,
                        y: position.y + sin(angle) * currentDistance + yOffset
                    )
                    
                    // Rotate spark
                    node.zRotation = angle + (.pi/2) * progress
                }
                
                // Create trail effect
                let trailAction = SKAction.customAction(withDuration: duration) { node, time in
                    if time > 0.05 {  // Quick trail start
                        let trail = SKShapeNode(path: sparkPath)
                        trail.strokeColor = spark.strokeColor.withAlphaComponent(0.2)
                        trail.lineWidth = spark.lineWidth * 0.5
                        trail.position = node.position
                        trail.zRotation = node.zRotation
                        self.addChild(trail)
                        
                        let fadeOut = SKAction.sequence([
                            SKAction.fadeOut(withDuration: 0.1),
                            SKAction.removeFromParent()
                        ])
                        trail.run(fadeOut)
                    }
                }
                
                let fadeAction = SKAction.sequence([
                    SKAction.wait(forDuration: duration * 0.6),
                    SKAction.fadeOut(withDuration: duration * 0.4)
                ])
                
                let group = SKAction.group([moveAction, fadeAction, trailAction])
                let remove = SKAction.removeFromParent()
                
                let delay = SKAction.wait(forDuration: popDelay)
                spark.run(SKAction.sequence([delay, group, remove]))
            }
        }
        
        // Add central flash
        let flash = SKShapeNode(circleOfRadius: 10)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.position = position
        flash.alpha = 0.9
        addChild(flash)
        
        let flashFade = SKAction.fadeOut(withDuration: 0.2)
        let removeFlash = SKAction.removeFromParent()
        flash.run(SKAction.sequence([flashFade, removeFlash]))
    }
    
    private func createCrackles(at position: CGPoint, angle: CGFloat) {
        let numCrackles = 3
        let crackleLength: CGFloat = 8
        
        for _ in 0..<numCrackles {
            let crackle = SKShapeNode()
            let path = CGMutablePath()
            
            // Start at the given position
            path.move(to: .zero)
            
            // Create a zigzag pattern
            var currentPoint = CGPoint.zero
            let numZigs = 3
            
            for _ in 0..<numZigs {
                let zigAngle = angle + CGFloat.random(in: -0.5...0.5)
                let zagAngle = angle + CGFloat.random(in: -0.5...0.5)
                
                // Zig
                let zigEnd = CGPoint(
                    x: currentPoint.x + cos(zigAngle) * crackleLength/CGFloat(numZigs),
                    y: currentPoint.y + sin(zigAngle) * crackleLength/CGFloat(numZigs)
                )
                path.addLine(to: zigEnd)
                currentPoint = zigEnd
                
                // Zag
                let zagEnd = CGPoint(
                    x: currentPoint.x + cos(zagAngle) * crackleLength/CGFloat(numZigs),
                    y: currentPoint.y + sin(zagAngle) * crackleLength/CGFloat(numZigs)
                )
                path.addLine(to: zagEnd)  // Fixed typo here
                currentPoint = zagEnd  // Fixed typo here
            }
            
            crackle.path = path
            crackle.strokeColor = NSColor(
                hue: CGFloat.random(in: 0...1),
                saturation: 1.0,
                brightness: 1.0,
                alpha: 1.0
            )
            crackle.lineWidth = 1
            crackle.position = position
            addChild(crackle)
            
            // Animate crackles
            let duration = CGFloat.random(in: 0.1...0.2)
            let fadeAction = SKAction.fadeOut(withDuration: duration)
            let scaleAction = SKAction.scale(by: 0.5, duration: duration)
            let rotateAction = SKAction.rotate(byAngle: CGFloat.random(in: -0.3...0.3), duration: duration)
            let group = SKAction.group([fadeAction, scaleAction, rotateAction])
            let remove = SKAction.removeFromParent()
            
            // Add slight random delay
            let delay = SKAction.wait(forDuration: Double.random(in: 0...0.1))
            crackle.run(SKAction.sequence([delay, group, remove]))
        }
    }
    
    // Add at top with other properties
    private var isTestingMode = true  // Set to false to return to normal mode
    
    func handleGameOver() {
        gameState = .gameOver
        playSound("game_over")
        
        // Show game over text
        let gameOverLabel = SKLabelNode(text: "Game Over")
        gameOverLabel.fontName = "Helvetica-Bold"
        gameOverLabel.fontSize = 48
        gameOverLabel.position = CGPoint(x: size.width/2, y: size.height/2)
        gameOverLabel.zPosition = 100
        addChild(gameOverLabel)
        
        // Show "Press Space to Start" text
        let pressSpaceLabel = SKLabelNode(text: "Press Space to Start")
        pressSpaceLabel.fontName = "Helvetica"
        pressSpaceLabel.fontSize = 24
        pressSpaceLabel.position = CGPoint(x: size.width/2, y: size.height/2 - 40)
        pressSpaceLabel.zPosition = 100
        addChild(pressSpaceLabel)
    }
    
    // Add with other properties
    private var gameState: GameState = .title
}

// Extension to prevent stroke scaling
extension SKShapeNode {
    func setLineWidthWithoutScaling(_ width: CGFloat) {
        self.lineWidth = width
        // Store the original line width for later adjustments if needed
        self.userData = self.userData ?? NSMutableDictionary()
        #if hasFeature(Embedded)
        self.userData?["originalLineWidth"] = .double(Double(width))
        #else
        self.userData?["originalLineWidth"] = width
        #endif
    }
}

