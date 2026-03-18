import AppKit
import Foundation
import HGSSDataModel
import SceneKit
import SwiftUI

public struct HGSSOpeningPlayerView: View {
    @ObservedObject private var controller: HGSSOpeningPlaybackController
    private let loadedBundle: LoadedOpeningBundle
    private let showDebugOverlay: Bool
    private let onBottomScreenTap: () -> Void

    public init(
        loadedBundle: LoadedOpeningBundle,
        controller: HGSSOpeningPlaybackController,
        showDebugOverlay: Bool = false,
        onBottomScreenTap: @escaping () -> Void = {}
    ) {
        self.loadedBundle = loadedBundle
        self.controller = controller
        self.showDebugOverlay = showDebugOverlay
        self.onBottomScreenTap = onBottomScreenTap
    }

    public var body: some View {
        GeometryReader { geometry in
            let topScreen = loadedBundle.bundle.topScreen
            let bottomScreen = loadedBundle.bundle.bottomScreen
            let chromePadding: CGFloat = 24
            let availableWidth = max(0, geometry.size.width - (chromePadding * 2))
            let availableHeight = max(0, geometry.size.height - (chromePadding * 2))
            let scale = HGSSDualScreenLayout.integerScale(
                containerWidth: availableWidth,
                containerHeight: availableHeight,
                nativeWidth: topScreen.width,
                topHeight: topScreen.height,
                bottomHeight: bottomScreen.height,
                screenGap: 18
            )
            let scaledWidth = CGFloat(topScreen.width * scale)
            let scaledHeight = CGFloat((topScreen.height + bottomScreen.height) * scale) + (18 * CGFloat(scale))

            VStack(spacing: 18) {
                openingScreenView(screen: .top, size: topScreen)
                    .frame(width: CGFloat(topScreen.width), height: CGFloat(topScreen.height))

                openingScreenView(screen: .bottom, size: bottomScreen)
                    .frame(width: CGFloat(bottomScreen.width), height: CGFloat(bottomScreen.height))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onBottomScreenTap()
                    }
            }
            .scaleEffect(CGFloat(scale), anchor: .center)
            .frame(
                width: scaledWidth,
                height: scaledHeight
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(chromePadding)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#040507"),
                        Color(hex: "#111014"),
                        Color(hex: "#20160E")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    @ViewBuilder
    private func openingScreenView(
        screen: HGSSOpeningBundle.ScreenID,
        size: HGSSOpeningBundle.NativeScreen
    ) -> some View {
        let scene = controller.currentScene
        let frame = controller.state.frameInScene
        let screenLayers = layers(for: screen, scene: scene, frame: frame)
        let screenSprites = spriteAnimations(for: screen, scene: scene, frame: frame)
        let screenModels = modelAnimations(for: screen, scene: scene, frame: frame)
        let screenBrightness = overlayForScreen(screen, scene: scene, frame: frame)
        let maskState = maskStateForScreen(screen, scene: scene, frame: frame, size: size)
        let circleWipeState = circleWipeStateForScreen(screen, scene: scene, frame: frame)

        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                ForEach(screenLayers, id: \.id) { layer in
                    openingLayerView(layer: layer, scene: scene, frame: frame)
                }

                ForEach(screenSprites, id: \.id) { animation in
                    openingSpriteView(animation: animation, scene: scene, frame: frame)
                }

                ForEach(screenModels, id: \.id) { model in
                    openingModelView(model: model, sceneFrame: frame)
                }
            }
            .frame(width: CGFloat(size.width), height: CGFloat(size.height), alignment: .topLeading)
            .clipped()
            .mask(
                screenMask(
                    width: CGFloat(size.width),
                    height: CGFloat(size.height),
                    maskState: maskState
                )
            )

            if let circleWipeState {
                Rectangle()
                    .fill(circleWipeState.color)
                    .frame(width: CGFloat(size.width), height: CGFloat(size.height))
                    .mask(
                        circleWipeMask(
                            width: CGFloat(size.width),
                            height: CGFloat(size.height),
                            state: circleWipeState
                        )
                    )
            }

            if let screenBrightness {
                Rectangle()
                    .fill(screenBrightness.color.opacity(screenBrightness.opacity))
                    .frame(width: CGFloat(size.width), height: CGFloat(size.height))
            }

            if showDebugOverlay {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.id.rawValue)
                    Text("frame \(frame)/\(scene.durationFrames - 1)")
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .padding(8)
                .foregroundStyle(.white)
                .background(Color.black.opacity(0.45))
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.black.opacity(0.92), lineWidth: 4)
        )
        .background(Color.black)
        .clipped()
    }

    private func layers(
        for screen: HGSSOpeningBundle.ScreenID,
        scene: HGSSOpeningBundle.Scene,
        frame: Int
    ) -> [HGSSOpeningBundle.LayerRef] {
        let layers = screen == .top ? scene.topLayers : scene.bottomLayers
        return layers
            .filter { isActive(startFrame: $0.startFrame, endFrame: $0.endFrame, frame: frame) }
            .sorted { lhs, rhs in
                lhs.zIndex == rhs.zIndex ? lhs.id < rhs.id : lhs.zIndex < rhs.zIndex
            }
    }

    private func spriteAnimations(
        for screen: HGSSOpeningBundle.ScreenID,
        scene: HGSSOpeningBundle.Scene,
        frame: Int
    ) -> [HGSSOpeningBundle.SpriteAnimationRef] {
        scene.spriteAnimations
            .filter { $0.screen == screen && isActive(startFrame: $0.startFrame, endFrame: $0.endFrame, frame: frame) }
            .sorted { lhs, rhs in
                lhs.zIndex == rhs.zIndex ? lhs.id < rhs.id : lhs.zIndex < rhs.zIndex
            }
    }

    private func modelAnimations(
        for screen: HGSSOpeningBundle.ScreenID,
        scene: HGSSOpeningBundle.Scene,
        frame: Int
    ) -> [HGSSOpeningBundle.ModelAnimationRef] {
        scene.modelAnimations
            .filter { $0.screen == screen && isActive(startFrame: $0.startFrame, endFrame: $0.endFrame, frame: frame) }
            .sorted { lhs, rhs in
                lhs.zIndex == rhs.zIndex ? lhs.id < rhs.id : lhs.zIndex < rhs.zIndex
            }
    }

    private func openingLayerView(
        layer: HGSSOpeningBundle.LayerRef,
        scene: HGSSOpeningBundle.Scene,
        frame: Int
    ) -> some View {
        let scrollOffset = scrollOffsetForTarget(layer.id, scene: scene, frame: frame)
        let frameRect = layer.screenRect
        let tiledOffsets = tiledLayerOffsets(for: layer)

        return Group {
            if let image = try? loadedBundle.assetURL(id: layer.assetID).image {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(tiledOffsets.enumerated()), id: \.0) { _, tiledOffset in
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: CGFloat(frameRect.width), height: CGFloat(frameRect.height))
                            .position(
                                x: CGFloat(frameRect.x) + scrollOffset.width + tiledOffset.width + (CGFloat(frameRect.width) / 2.0),
                                y: CGFloat(frameRect.y) + scrollOffset.height + tiledOffset.height + (CGFloat(frameRect.height) / 2.0)
                            )
                    }
                }
            } else {
                Color.black
            }
        }
        .opacity(layer.opacity)
    }

    private func tiledLayerOffsets(for layer: HGSSOpeningBundle.LayerRef) -> [CGSize] {
        guard layer.wraps else {
            return [.zero]
        }

        let xStride = CGFloat(layer.screenRect.width)
        let yStride = CGFloat(layer.screenRect.height)
        return [
            CGSize(width: -xStride, height: -yStride),
            CGSize(width: 0, height: -yStride),
            CGSize(width: xStride, height: -yStride),
            CGSize(width: -xStride, height: 0),
            CGSize(width: 0, height: 0),
            CGSize(width: xStride, height: 0),
            CGSize(width: -xStride, height: yStride),
            CGSize(width: 0, height: yStride),
            CGSize(width: xStride, height: yStride),
        ]
    }

    private func openingSpriteView(
        animation: HGSSOpeningBundle.SpriteAnimationRef,
        scene: HGSSOpeningBundle.Scene,
        frame: Int
    ) -> some View {
        let relativeFrame = max(0, frame - animation.startFrame)
        let frameIndex: Int
        if animation.loop {
            frameIndex = (relativeFrame / max(1, animation.frameDurationFrames)) % max(1, animation.frameAssetIDs.count)
        } else {
            frameIndex = min(
                animation.frameAssetIDs.count - 1,
                relativeFrame / max(1, animation.frameDurationFrames)
            )
        }

        let assetID = animation.frameAssetIDs[frameIndex]
        let scrollOffset = scrollOffsetForTarget(animation.id, scene: scene, frame: frame)
        let frameRect = animation.screenRect

        return Group {
            if let image = try? loadedBundle.assetURL(id: assetID).image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
            } else {
                Color.clear
            }
        }
        .frame(width: CGFloat(frameRect.width), height: CGFloat(frameRect.height))
        .position(
            x: CGFloat(frameRect.x) + scrollOffset.width + (CGFloat(frameRect.width) / 2.0),
            y: CGFloat(frameRect.y) + scrollOffset.height + (CGFloat(frameRect.height) / 2.0)
        )
    }

    private func openingModelView(
        model: HGSSOpeningBundle.ModelAnimationRef,
        sceneFrame: Int
    ) -> some View {
        let frameRect = model.screenRect
        return SceneModelView(
            model: model,
            url: try? loadedBundle.assetURL(id: model.assetID),
            sceneFrame: sceneFrame
        )
            .frame(width: CGFloat(frameRect.width), height: CGFloat(frameRect.height))
            .position(
                x: CGFloat(frameRect.x) + (CGFloat(frameRect.width) / 2.0),
                y: CGFloat(frameRect.y) + (CGFloat(frameRect.height) / 2.0)
            )
    }

    private func overlayForScreen(
        _ screen: HGSSOpeningBundle.ScreenID,
        scene: HGSSOpeningBundle.Scene,
        frame: Int
    ) -> (color: Color, opacity: Double)? {
        let relevantCue = scene.transitionCues
            .filter {
                ($0.kind == .fade || $0.kind == .brightness) &&
                    $0.screen == screen &&
                    frame >= $0.startFrame
            }
            .sorted { lhs, rhs in
                lhs.startFrame == rhs.startFrame ? lhs.id < rhs.id : lhs.startFrame < rhs.startFrame
            }
            .last
        guard let relevantCue else {
            return nil
        }

        let progress = transitionProgressIncludingCompletion(for: relevantCue, frame: frame)
        let fromValue = relevantCue.fromValue ?? 0.0
        let toValue = relevantCue.toValue ?? 0.0
        let opacity = interpolate(from: fromValue, to: toValue, progress: progress)
        let color = Color(hex: relevantCue.colorHex ?? "#FFFFFF")
        return (color, opacity)
    }

    private func scrollOffsetForTarget(
        _ targetID: String,
        scene: HGSSOpeningBundle.Scene,
        frame: Int
    ) -> CGSize {
        let cues = scene.transitionCues.filter {
            $0.kind == .scroll &&
                $0.targetID == targetID &&
                frame >= $0.startFrame
        }

        return cues.reduce(.zero) { partialResult, cue in
            let progress = transitionProgressIncludingCompletion(for: cue, frame: frame)
            return CGSize(
                width: partialResult.width + interpolate(from: 0, to: cue.offsetX ?? 0, progress: progress),
                height: partialResult.height + interpolate(from: 0, to: cue.offsetY ?? 0, progress: progress)
            )
        }
    }

    private func maskStateForScreen(
        _ screen: HGSSOpeningBundle.ScreenID,
        scene: HGSSOpeningBundle.Scene,
        frame: Int,
        size: HGSSOpeningBundle.NativeScreen
    ) -> ScreenMaskState {
        let fullRect = CGRect(x: 0, y: 0, width: CGFloat(size.width), height: CGFloat(size.height))
        let activeCues = scene.transitionCues
            .filter {
                $0.screen == screen &&
                    $0.kind != .circleWipe &&
                    frame >= $0.startFrame
            }
            .sorted { lhs, rhs in
                lhs.startFrame == rhs.startFrame ? lhs.id < rhs.id : lhs.startFrame < rhs.startFrame
            }

        guard let cue = activeCues.last(where: { $0.kind == .window || $0.kind == .viewport }) else {
            return .full
        }

        switch cue.kind {
        case .window, .viewport:
            if let fromRect = cue.fromRect, let toRect = cue.toRect {
                let progress = transitionProgressIncludingCompletion(for: cue, frame: frame)
                let mainRect = interpolateRect(from: fromRect, to: toRect, progress: progress)
                if let auxiliaryFromRect = cue.auxiliaryFromRect, let auxiliaryToRect = cue.auxiliaryToRect {
                    let auxiliaryRect = interpolateRect(from: auxiliaryFromRect, to: auxiliaryToRect, progress: progress)
                    return .multiRect([mainRect, auxiliaryRect])
                }
                return .rect(mainRect)
            }

            let progress = transitionProgressIncludingCompletion(for: cue, frame: frame)
            let fromValue = cue.fromValue ?? 0
            let toValue = cue.toValue ?? 0
            let inset = CGFloat(interpolate(from: fromValue, to: toValue, progress: progress))
            if cue.kind == .viewport {
                return .rect(fullRect.insetBy(dx: inset, dy: 0))
            }
            return .rect(fullRect.insetBy(dx: 0, dy: inset))
        default:
            return .full
        }
    }

    private func circleWipeStateForScreen(
        _ screen: HGSSOpeningBundle.ScreenID,
        scene: HGSSOpeningBundle.Scene,
        frame: Int
    ) -> CircleWipeOverlayState? {
        let activeCue = scene.transitionCues
            .filter {
                $0.kind == .circleWipe &&
                    $0.screen == screen &&
                    frame >= $0.startFrame
            }
            .sorted { lhs, rhs in
                lhs.startFrame == rhs.startFrame ? lhs.id < rhs.id : lhs.startFrame < rhs.startFrame
            }
            .last

        guard let activeCue else {
            return nil
        }

        let durationFrames = max(1, activeCue.durationFrames)
        let counter = min(max(frame - activeCue.startFrame, 0), durationFrames - 1)
        let mode = activeCue.mode ?? (activeCue.revealsInside == true ? 1 : 0)
        return CircleWipeOverlayState(
            counter: counter,
            durationFrames: durationFrames,
            coversInside: mode == 0 || mode == 2,
            color: Color(hex: activeCue.colorHex ?? "#000000")
        )
    }

    @ViewBuilder
    private func screenMask(
        width: CGFloat,
        height: CGFloat,
        maskState: ScreenMaskState
    ) -> some View {
        switch maskState {
        case .full:
            Rectangle()
                .fill(.white)
                .frame(width: width, height: height)
        case let .rect(rect):
            Rectangle()
                .fill(.white)
                .frame(width: max(0, rect.width), height: max(0, rect.height))
                .position(x: rect.midX, y: rect.midY)
        case let .multiRect(rects):
            ZStack(alignment: .topLeading) {
                ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                    Rectangle()
                        .fill(.white)
                        .frame(width: max(0, rect.width), height: max(0, rect.height))
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .frame(width: width, height: height)
        }
    }

    @ViewBuilder
    private func circleWipeMask(
        width: CGFloat,
        height: CGFloat,
        state: CircleWipeOverlayState
    ) -> some View {
        LineWipeMaskShape(state: .init(counter: state.counter, durationFrames: state.durationFrames))
            .fill(.white, style: FillStyle(eoFill: !state.coversInside))
            .frame(width: width, height: height)
    }

    private func interpolateRect(
        from: HGSSOpeningBundle.ScreenRect,
        to: HGSSOpeningBundle.ScreenRect,
        progress: Double
    ) -> CGRect {
        CGRect(
            x: interpolate(from: from.x, to: to.x, progress: progress),
            y: interpolate(from: from.y, to: to.y, progress: progress),
            width: interpolate(from: from.width, to: to.width, progress: progress),
            height: interpolate(from: from.height, to: to.height, progress: progress)
        )
    }

    private func isActive(startFrame: Int, endFrame: Int?, frame: Int) -> Bool {
        guard frame >= startFrame else {
            return false
        }
        if let endFrame {
            return frame <= endFrame
        }
        return true
    }

    private func transitionProgress(
        for cue: HGSSOpeningBundle.TransitionCue,
        frame: Int
    ) -> Double {
        guard cue.durationFrames > 0 else {
            return 1.0
        }

        let relativeFrame = max(1, min((frame - cue.startFrame) + 1, cue.durationFrames))
        return Double(relativeFrame) / Double(cue.durationFrames)
    }

    private func transitionProgressIncludingCompletion(
        for cue: HGSSOpeningBundle.TransitionCue,
        frame: Int
    ) -> Double {
        guard cue.durationFrames > 0 else {
            return 1.0
        }
        guard frame >= cue.startFrame else {
            return 0.0
        }
        if frame > transitionEndFrame(for: cue) {
            return 1.0
        }
        return transitionProgress(for: cue, frame: frame)
    }

    private func transitionEndFrame(for cue: HGSSOpeningBundle.TransitionCue) -> Int {
        cue.startFrame + max(0, cue.durationFrames - 1)
    }

    private func interpolate(from: Double, to: Double, progress: Double) -> Double {
        from + ((to - from) * progress)
    }
}

private enum ScreenMaskState {
    case full
    case rect(CGRect)
    case multiRect([CGRect])
}

private struct LineWipeMaskState {
    let counter: Int
    let durationFrames: Int
}

private struct CircleWipeOverlayState {
    let counter: Int
    let durationFrames: Int
    let coversInside: Bool
    let color: Color
}

private struct LineWipeMaskShape: Shape {
    let state: LineWipeMaskState

    func path(in rect: CGRect) -> Path {
        let boundary = lineBoundaryPoints(in: rect)
        var path = Path()
        path.move(to: .init(x: rect.minX, y: rect.minY))
        for point in boundary {
            path.addLine(to: point)
        }
        path.addLine(to: .init(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    private func lineBoundaryPoints(in rect: CGRect) -> [CGPoint] {
        let counter = min(max(state.counter, 0), max(0, state.durationFrames - 1))
        let theta = Double.pi * Double(counter) / Double(max(1, state.durationFrames))
        let cosine = cos(theta)
        let sine = sin(theta)

        return (0..<Int(rect.height)).map { scanline in
            let boundaryX: CGFloat
            if abs(cosine - 1.0) < 0.0001 {
                boundaryX = rect.maxX - 1.0
            } else if abs(cosine + 1.0) < 0.0001 || sine <= 0 {
                boundaryX = rect.minX
            } else {
                let raw = 127.0 + CGFloat((Double(scanline) * cosine) / sine)
                boundaryX = min(rect.maxX - 1, max(rect.minX, raw))
            }
            return CGPoint(x: boundaryX, y: rect.minY + CGFloat(scanline))
        }
    }
}

private struct SceneModelView: NSViewRepresentable {
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

private extension URL {
    var image: NSImage? {
        NSImage(contentsOf: self)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        switch cleaned.count {
        case 6:
            red = Double((value >> 16) & 0xFF) / 255.0
            green = Double((value >> 8) & 0xFF) / 255.0
            blue = Double(value & 0xFF) / 255.0
        default:
            red = 1.0
            green = 1.0
            blue = 1.0
        }

        self.init(red: red, green: green, blue: blue)
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
