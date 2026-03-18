import AppKit
import Foundation
import HGSSDataModel
import SceneKit
import SwiftUI

struct SceneModelView: NSViewRepresentable {
    let model: HGSSOpeningBundle.ModelAnimationRef
    let url: URL?
    let sceneFrame: Int

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = model.lights.isEmpty
        view.allowsCameraControl = false
        view.isPlaying = false
        view.antialiasingMode = .none
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        guard let url else {
            nsView.scene = nil
            nsView.pointOfView = nil
            return
        }
        if nsView.scene == nil || context.coordinator.loadedURL != url || context.coordinator.loadedModelID != model.id {
            context.coordinator.loadedURL = url
            context.coordinator.loadedModelID = model.id
            let scene = try? SCNScene(url: url, options: nil)
            applyConfiguration(to: scene)
            configureAnimationPlayers(in: scene)
            nsView.scene = scene
            nsView.pointOfView = scene?.rootNode.childNode(withName: "openingCamera", recursively: false)
        }
        nsView.sceneTime = sceneTime(for: model, sceneFrame: sceneFrame)
    }

    private func applyConfiguration(to scene: SCNScene?) {
        guard let scene else {
            return
        }

        if let translation = model.translation {
            scene.rootNode.position = SCNVector3(translation)
        }

        if let camera = model.camera {
            let cameraNode = SCNNode()
            let scnCamera = SCNCamera()
            if let fieldOfViewDegrees = camera.fieldOfViewDegrees {
                scnCamera.fieldOfView = fieldOfViewDegrees
            }
            if let nearClipDistance = camera.nearClipDistance {
                scnCamera.zNear = max(0.001, nearClipDistance)
            }
            if let farClipDistance = sceneKitFarClipDistance(for: camera) {
                scnCamera.zFar = farClipDistance
            }
            cameraNode.name = "openingCamera"
            cameraNode.camera = scnCamera
            cameraNode.position = SCNVector3(camera.position)
            cameraNode.look(at: SCNVector3(camera.target))
            scene.rootNode.addChildNode(cameraNode)
        }

        if !model.lights.isEmpty {
            scene.rootNode.enumerateChildNodes { node, _ in
                if node.light != nil {
                    node.removeFromParentNode()
                }
            }

            for lightState in model.lights {
                let directionVector = SIMD3<Float>(
                    Float(lightState.direction.x),
                    Float(lightState.direction.y),
                    Float(lightState.direction.z)
                )
                guard simd_length_squared(directionVector) > 0.000001 else {
                    continue
                }

                let lightNode = SCNNode()
                let light = SCNLight()
                light.type = .directional
                light.color = NSColor(lightState.colorHex)
                lightNode.light = light

                let direction = simd_normalize(directionVector)
                lightNode.simdLook(at: direction, up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
                scene.rootNode.addChildNode(lightNode)
            }
        }

        if let materialState = model.material {
            scene.rootNode.enumerateHierarchy { node, _ in
                guard let geometry = node.geometry else {
                    return
                }

                for material in geometry.materials {
                    if let diffuseHex = materialState.diffuseHex {
                        material.multiply.contents = NSColor(diffuseHex)
                    }
                    if let ambientHex = materialState.ambientHex {
                        material.ambient.contents = NSColor(ambientHex)
                    }
                    if let specularHex = materialState.specularHex {
                        material.specular.contents = NSColor(specularHex)
                    }
                    if let emissionHex = materialState.emissionHex {
                        material.emission.contents = NSColor(emissionHex)
                    }
                }
            }
        }

        scene.isPaused = false
    }

    private func configureAnimationPlayers(in scene: SCNScene?) {
        guard let scene else {
            return
        }

        scene.rootNode.enumerateHierarchy { node, _ in
            for key in node.animationKeys {
                if let player = node.animationPlayer(forKey: key) {
                    player.animation.usesSceneTimeBase = true
                    player.animation.repeatCount = model.loop ? .greatestFiniteMagnitude : 0
                    player.paused = false
                    player.speed = 1.0
                    player.play()
                }
            }
        }
    }

    private func sceneTime(for model: HGSSOpeningBundle.ModelAnimationRef, sceneFrame: Int) -> TimeInterval {
        let frameValue: Double
        if let freezeAtFrame = model.freezeAtFrame {
            frameValue = freezeAtFrame
        } else {
            let relativeFrame = max(0, sceneFrame - model.startFrame)
            if model.loop {
                frameValue = Double(relativeFrame)
            } else if let endFrame = model.endFrame {
                frameValue = Double(min(relativeFrame, max(0, endFrame - model.startFrame)))
            } else {
                frameValue = Double(relativeFrame)
            }
        }
        return frameValue / HGSSOpeningPlaybackController.framesPerSecond
    }

    private func sceneKitFarClipDistance(
        for camera: HGSSOpeningBundle.ModelAnimationRef.CameraState
    ) -> Double? {
        guard let farClipDistance = camera.farClipDistance else {
            return nil
        }

        let dx = camera.position.x - camera.target.x
        let dy = camera.position.y - camera.target.y
        let dz = camera.position.z - camera.target.z
        let targetDistance = sqrt((dx * dx) + (dy * dy) + (dz * dz))
        guard farClipDistance > targetDistance else {
            return nil
        }
        return farClipDistance
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadedURL: URL?
        var loadedModelID: String?
    }
}

private extension SCNVector3 {
    init(_ vector: HGSSOpeningBundle.Vector3) {
        self.init(vector.x, vector.y, vector.z)
    }
}

private extension NSColor {
    convenience init(_ hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
