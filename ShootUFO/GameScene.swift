//
//  GameScene.swift
//  ShootUFO
//
//  Created by behlul on 27.12.2017.
//  Copyright © 2017 behlul. All rights reserved.
//

import SpriteKit
import GameplayKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var starField: SKEmitterNode!
    var player: SKSpriteNode!
    var scoreLabel: SKLabelNode!
    
    var possibleAliens = ["alien", "alien2", "alien3"]
    var score: Int = 0{
        didSet{
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    var gameTimer: Timer!
    var WIDTH: CGFloat!
    var HEIGHT: CGFloat!
    let alienCategory: UInt32 = 0x01 << 1
    let photonTorpedoCategory: UInt32 = 0x01 << 0
    let motionManager = CMMotionManager()
    var xAcceleration: CGFloat = 0
    
    override func didMove(to view: SKView) {
        
        WIDTH = self.frame.size.width
        HEIGHT = self.frame.size.height
        
        starField = SKEmitterNode(fileNamed: "Starfield")
        starField.position = CGPoint(x: 0.0, y: HEIGHT)
        starField.advanceSimulationTime(10)
        starField.zPosition = -1
        self.addChild(starField)
        
        player = SKSpriteNode(imageNamed: "shuttle")
        player.position = CGPoint(x: 0, y: -HEIGHT / 2 + 100)
        self.addChild(player)
        
        self.physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        self.physicsWorld.contactDelegate = self
        
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.position = CGPoint(x: -WIDTH / 2 + scoreLabel.frame.size.width, y: HEIGHT / 2 - 60)
        scoreLabel.fontName = "AmericanTypewriter-Bold"
        scoreLabel.fontSize = 42
        scoreLabel.fontColor = UIColor.white
        self.addChild(scoreLabel)
        
        gameTimer = Timer.scheduledTimer(timeInterval: 0.75, target: self, selector: #selector(addAlien), userInfo: nil, repeats: true)
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { (data: CMAccelerometerData?, error: Error?) in
            if let accelerometerData = data {
                let acceleration = accelerometerData.acceleration
                self.xAcceleration = CGFloat(acceleration.x * 50)
                print("acceleration x: \(self.xAcceleration)")
            }
        }
    }
    
    @objc func addAlien() {
        guard let shuffeldArray = GKRandomSource.sharedRandom().arrayByShufflingObjects(in: possibleAliens) as? [String] else { return }
        possibleAliens = shuffeldArray
        
        let alien = SKSpriteNode(imageNamed: possibleAliens[0])
        let randomAlienPosition = GKRandomDistribution(lowestValue: Int(-WIDTH/2)+16, highestValue: Int(WIDTH/2)-16)
        let positionX = CGFloat(randomAlienPosition.nextInt())
        
        alien.position = CGPoint(x: positionX, y: HEIGHT/2)
        alien.physicsBody = SKPhysicsBody(rectangleOf: alien.size)
        alien.physicsBody?.isDynamic = true
        
        alien.physicsBody?.categoryBitMask = alienCategory
        alien.physicsBody?.contactTestBitMask = photonTorpedoCategory
        alien.physicsBody?.collisionBitMask = 0
        
        self.addChild(alien)
        
        let animationDuration: TimeInterval = 6
        var actionArray = [SKAction]()
        let maxPositionY = -HEIGHT/2 - alien.size.height
        
        actionArray.append(SKAction.move(to: CGPoint(x: positionX, y: maxPositionY), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        
        alien.run(SKAction.sequence(actionArray))
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fireTorpedo()
    }
    
    func fireTorpedo() {
        self.run(SKAction.playSoundFileNamed("torpedo.mp3", waitForCompletion: false))
        
        let torpedoNode = SKSpriteNode(imageNamed: "torpedo")
        torpedoNode.position = player.position
        torpedoNode.position.y += 5
        
        torpedoNode.physicsBody = SKPhysicsBody(circleOfRadius: torpedoNode.size.width/2)
        torpedoNode.physicsBody?.isDynamic = true
        torpedoNode.physicsBody?.categoryBitMask = photonTorpedoCategory
        torpedoNode.physicsBody?.contactTestBitMask = alienCategory
        torpedoNode.physicsBody?.collisionBitMask = 0
        torpedoNode.physicsBody?.usesPreciseCollisionDetection = true
        
        self.addChild(torpedoNode)
        
        let animationDuration: TimeInterval = 1
        var actionArray = [SKAction]()
        
        actionArray.append(SKAction.move(to: CGPoint(x: player.position.x, y: HEIGHT/2 + 10), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        
        torpedoNode.run(SKAction.sequence(actionArray))
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        if (firstBody.categoryBitMask & photonTorpedoCategory) != 0 && (secondBody.categoryBitMask & alienCategory) != 0 {
            guard let t = firstBody.node as? SKSpriteNode, let a = secondBody.node as? SKSpriteNode else {
                print("firstBody and secondBody Error")
                return
            }
            torpidoDidCollideWithAlien(torpedoNode: t, alienNode: a)
        }

    }
    
    func torpidoDidCollideWithAlien(torpedoNode: SKSpriteNode, alienNode: SKSpriteNode) {
        guard let explosion = SKEmitterNode(fileNamed: "Explosion") else {
            print("Explosion SKEmitterNode cast Error")
            return
        }
        explosion.position = alienNode.position
        self.addChild(explosion)
        
        self.run(SKAction.playSoundFileNamed("explosion.mp3", waitForCompletion: false))
        torpedoNode.removeFromParent()
        alienNode.removeFromParent()
        self.run(SKAction.wait(forDuration: 1.5)) {
            explosion.removeFromParent()
        }
        
        score += 5
    }
    
    override func didSimulatePhysics() {
        var movePositionX: CGFloat
        if xAcceleration > 30 {
            movePositionX = 30
        } else if xAcceleration < -30 {
            movePositionX = -30
        } else {
            movePositionX = xAcceleration
        }
        let multiplayWith = (WIDTH/2)/30
        player.position.x = movePositionX * multiplayWith
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
