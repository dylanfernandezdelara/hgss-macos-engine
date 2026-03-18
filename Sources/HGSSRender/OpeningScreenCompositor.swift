import AppKit
import Foundation
import HGSSDataModel
import HGSSOpeningIR

@MainActor
final class HGSSOpeningScreenCompositor {
    private let loadedBundle: LoadedOpeningBundle
    private var imageCache: [String: CGImage] = [:]

    init(loadedBundle: LoadedOpeningBundle) {
        self.loadedBundle = loadedBundle
    }

    func render(
        screen: HGSSOpeningBundle.ScreenID,
        size: HGSSOpeningBundle.NativeScreen,
        controller: HGSSOpeningPlaybackController
    ) -> NSImage {
        let imageSize = NSSize(width: max(size.width, 1), height: max(size.height, 1))
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(imageSize.width),
            pixelsHigh: Int(imageSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: Int(imageSize.width) * 4,
            bitsPerPixel: 32
        ) else {
            return NSImage(size: imageSize)
        }

        bitmap.size = imageSize
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            return NSImage(size: imageSize)
        }
        NSGraphicsContext.current = context

        let cgContext = context.cgContext
        let screenRect = CGRect(origin: .zero, size: imageSize)
        cgContext.interpolationQuality = .none
        cgContext.setFillColor(NSColor.black.cgColor)
        cgContext.fill(screenRect)
        cgContext.translateBy(x: 0, y: imageSize.height)
        cgContext.scaleBy(x: 1, y: -1)

        if hasProgramSurfaceContent(for: screen, controller: controller) {
            drawProgramSurface(
                for: screen,
                screenRect: screenRect,
                controller: controller,
                context: cgContext
            )
        } else {
            drawBundleScene(
                for: screen,
                size: size,
                screenRect: screenRect,
                controller: controller,
                context: cgContext
            )
        }

        drawProgramOverlays(
            for: screen,
            screenRect: screenRect,
            controller: controller,
            context: cgContext
        )

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: imageSize)
        image.addRepresentation(bitmap)
        return image
    }

    private func drawBundleScene(
        for screen: HGSSOpeningBundle.ScreenID,
        size: HGSSOpeningBundle.NativeScreen,
        screenRect: CGRect,
        controller: HGSSOpeningPlaybackController,
        context: CGContext
    ) {
        let scene = controller.currentScene
        let frame = controller.state.frameInScene
        let screenLayers = layers(for: screen, scene: scene, frame: frame)
        let screenSprites = spriteAnimations(for: screen, scene: scene, frame: frame)
        let maskState = maskStateForScreen(screen, scene: scene, frame: frame, size: size)

        context.saveGState()
        clip(
            maskState: maskState,
            in: screenRect,
            context: context
        )

        for layer in screenLayers {
            drawLayer(
                layer,
                scene: scene,
                frame: frame,
                context: context
            )
        }

        for animation in screenSprites {
            drawSpriteAnimation(
                animation,
                scene: scene,
                frame: frame,
                context: context
            )
        }
        context.restoreGState()

        if let circleWipeState = circleWipeStateForScreen(screen, scene: scene, frame: frame) {
            drawCircleWipeOverlay(
                circleWipeState,
                in: screenRect,
                context: context
            )
        }

        if let brightnessOverlay = overlayForScreen(screen, scene: scene, frame: frame) {
            context.saveGState()
            context.setFillColor(brightnessOverlay.color.withAlphaComponent(brightnessOverlay.opacity).cgColor)
            context.fill(screenRect)
            context.restoreGState()
        }
    }

    private func drawProgramSurface(
        for screen: HGSSOpeningBundle.ScreenID,
        screenRect: CGRect,
        controller: HGSSOpeningPlaybackController,
        context: CGContext
    ) {
        let programScreen = programScreenID(for: screen)
        if let fill = controller.activeSolidFill(screen: programScreen) {
            context.saveGState()
            context.setFillColor(nsColor(hex: fill.colorHex).cgColor)
            context.fill(screenRect)
            context.restoreGState()
        }

        if let messageBox = controller.activeMessageBox(screen: programScreen) {
            drawMessageBox(messageBox, context: context)
        }

        if let menu = controller.activeMenu(screen: programScreen) {
            drawMenu(
                menu,
                selectedOptionID: controller.resolvedMenuSelectionID(for: menu),
                frameInProgramState: controller.state.frameInProgramState,
                context: context
            )
        }
    }

    private func drawProgramOverlays(
        for screen: HGSSOpeningBundle.ScreenID,
        screenRect: CGRect,
        controller: HGSSOpeningPlaybackController,
        context: CGContext
    ) {
        let programScreen = programScreenID(for: screen)

        if let prompt = controller.activePromptCommand(screen: programScreen),
           controller.isProgramLayerVisible(prompt.targetID) != false,
           controller.isProgramPlaneVisible(screen: programScreen, planeID: "main_bg3") != false {
            drawPrompt(prompt, context: context)
        }

        if let glowOverlay = controller.activeProgramGlowOverlay(screen: programScreen) {
            context.saveGState()
            context.setFillColor(
                nsColor(hex: glowOverlay.colorHex)
                    .withAlphaComponent(glowOverlay.opacity)
                    .cgColor
            )
            context.fill(screenRect)
            context.restoreGState()
        }

        if let fadeOverlay = controller.activeProgramFadeOverlay() {
            context.saveGState()
            context.setFillColor(
                nsColor(hex: fadeOverlay.colorHex)
                    .withAlphaComponent(fadeOverlay.opacity)
                    .cgColor
            )
            context.fill(screenRect)
            context.restoreGState()
        }
    }

    private func drawLayer(
        _ layer: HGSSOpeningBundle.LayerRef,
        scene: HGSSOpeningBundle.Scene,
        frame: Int,
        context: CGContext
    ) {
        guard let image = cgImage(forAssetID: layer.assetID) else {
            return
        }

        let scrollOffset = scrollOffsetForTarget(layer.id, scene: scene, frame: frame)
        let frameRect = rect(from: layer.screenRect)
        let tiledOffsets = tiledLayerOffsets(for: layer)

        for tiledOffset in tiledOffsets {
            let drawRect = frameRect.offsetBy(
                dx: scrollOffset.width + tiledOffset.width,
                dy: scrollOffset.height + tiledOffset.height
            )
            context.saveGState()
            context.setAlpha(layer.opacity)
            drawImage(image, in: drawRect, context: context)
            context.restoreGState()
        }
    }

    private func drawSpriteAnimation(
        _ animation: HGSSOpeningBundle.SpriteAnimationRef,
        scene: HGSSOpeningBundle.Scene,
        frame: Int,
        context: CGContext
    ) {
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

        guard animation.frameAssetIDs.indices.contains(frameIndex),
              let image = cgImage(forAssetID: animation.frameAssetIDs[frameIndex]) else {
            return
        }

        let scrollOffset = scrollOffsetForTarget(animation.id, scene: scene, frame: frame)
        let frameRect = rect(from: animation.screenRect).offsetBy(
            dx: scrollOffset.width,
            dy: scrollOffset.height
        )
        drawImage(image, in: frameRect, context: context)
    }

    private func drawPrompt(
        _ prompt: HGSSOpeningProgramIR.PromptFlashCommand,
        context: CGContext
    ) {
        let rect = rect(from: prompt.rect ?? .init(x: 0, y: 144, width: 256, height: 16))
        let promptText = prompt.text ?? "TOUCH TO START"
        let style = HGSSDSGlyphTextStyle(
            foregroundPaletteIndex: 1,
            shadowPaletteIndex: 1,
            backgroundPaletteIndex: 0,
            letterSpacing: prompt.letterSpacing
        )

        if let glyphImage = glyphCGImage(text: promptText, style: style) {
            let drawRect = CGRect(
                x: rect.origin.x + ((rect.width - CGFloat(glyphImage.width)) / 2.0),
                y: rect.origin.y + ((rect.height - CGFloat(glyphImage.height)) / 2.0),
                width: CGFloat(glyphImage.width),
                height: CGFloat(glyphImage.height)
            )
            drawImage(glyphImage, in: drawRect, context: context)
        }
    }

    private func drawMessageBox(
        _ messageBox: HGSSOpeningProgramIR.MessageBoxCommand,
        context: CGContext
    ) {
        let rect = rect(from: messageBox.rect)
        let insets = messageBox.textInsets ?? .init(top: 4, left: 6, bottom: 4, right: 6)
        let text = messageBox.text.replacingOccurrences(of: "\\n", with: "\n")

        if let frameAssetID = messageBox.frameAssetID {
            drawNineSliceFrame(assetID: frameAssetID, in: rect, context: context)
        } else {
            let rounded = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            context.saveGState()
            context.setFillColor(NSColor(red: 0.08, green: 0.09, blue: 0.16, alpha: 1).cgColor)
            context.addPath(rounded.cgPath)
            context.fillPath()
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
            context.setLineWidth(2)
            context.addPath(rounded.cgPath)
            context.strokePath()
            context.restoreGState()
        }

        let textRect = CGRect(
            x: rect.origin.x + CGFloat(insets.left),
            y: rect.origin.y + CGFloat(insets.top),
            width: max(0, rect.width - CGFloat(insets.left + insets.right)),
            height: max(0, rect.height - CGFloat(insets.top + insets.bottom))
        )
        drawGlyphText(text, style: .body, in: textRect, centered: false, context: context)
    }

    private func drawMenu(
        _ menu: HGSSOpeningProgramIR.MenuCommand,
        selectedOptionID: String,
        frameInProgramState: Int,
        context: CGContext
    ) {
        guard let chrome = menu.chrome else {
            return
        }

        let scrollOffset = menuScrollOffset(menu, selectedOptionID: selectedOptionID)

        for (index, option) in menu.options.enumerated() {
            let rect = rect(from: menuOptionRect(menu, index: index, scrollOffset: scrollOffset))
            let isSelected = option.id == selectedOptionID
            let frameAssetID = isSelected
                ? (chrome.selectedFrameAssetID ?? chrome.normalFrameAssetID)
                : chrome.normalFrameAssetID

            if let frameAssetID {
                drawNineSliceFrame(assetID: frameAssetID, in: rect, context: context)
            }

            if let wirelessIconType = option.wirelessIconType,
               let wifiIconSheetAssetID = chrome.wifiIconSheetAssetID,
               let wifiIcon = cropWifiIcon(assetID: wifiIconSheetAssetID, type: wirelessIconType) {
                let iconRect = CGRect(x: rect.maxX - 16, y: rect.minY, width: 16, height: 16)
                drawImage(wifiIcon, in: iconRect, context: context)
            }

            let textRect = CGRect(
                x: rect.origin.x + 20,
                y: rect.origin.y + 4,
                width: max(0, rect.width - 40),
                height: max(0, rect.height - 8)
            )
            context.saveGState()
            context.setAlpha(option.enabled ? 1.0 : 0.6)
            drawGlyphText(
                option.text.replacingOccurrences(of: "\\n", with: "\n"),
                style: .body,
                in: textRect,
                centered: false,
                context: context
            )
            context.restoreGState()
        }

        if let upArrowRect = chrome.upArrowRect,
           chrome.upArrowFrameAssetIDs.isEmpty == false,
           scrollOffset > 0 {
            drawArrowAnimation(
                frameAssetIDs: chrome.upArrowFrameAssetIDs,
                in: rect(from: upArrowRect),
                frameInProgramState: frameInProgramState,
                context: context
            )
        }

        if let downArrowRect = chrome.downArrowRect,
           chrome.downArrowFrameAssetIDs.isEmpty == false,
           menuContentHeight(menu) - scrollOffset > 192 {
            drawArrowAnimation(
                frameAssetIDs: chrome.downArrowFrameAssetIDs,
                in: rect(from: downArrowRect),
                frameInProgramState: frameInProgramState,
                context: context
            )
        }
    }

    private func drawArrowAnimation(
        frameAssetIDs: [String],
        in rect: CGRect,
        frameInProgramState: Int,
        context: CGContext
    ) {
        let frameIndex = frameAssetIDs.isEmpty ? 0 : (frameInProgramState / 4) % frameAssetIDs.count
        guard frameAssetIDs.indices.contains(frameIndex),
              let image = cgImage(forAssetID: frameAssetIDs[frameIndex]) else {
            return
        }
        drawImage(image, in: rect, context: context)
    }

    private func drawGlyphText(
        _ text: String,
        style: HGSSDSGlyphTextStyle,
        in rect: CGRect,
        centered: Bool,
        context: CGContext
    ) {
        guard let glyphImage = glyphCGImage(text: text, style: style) else {
            return
        }

        let originX = centered
            ? rect.origin.x + ((rect.width - CGFloat(glyphImage.width)) / 2.0)
            : rect.origin.x
        let originY = centered
            ? rect.origin.y + ((rect.height - CGFloat(glyphImage.height)) / 2.0)
            : rect.origin.y
        let drawRect = CGRect(
            x: originX,
            y: originY,
            width: CGFloat(glyphImage.width),
            height: CGFloat(glyphImage.height)
        )
        drawImage(glyphImage, in: drawRect, context: context)
    }

    private func drawNineSliceFrame(
        assetID: String,
        in rect: CGRect,
        context: CGContext
    ) {
        guard let tiles = nineSliceTiles(assetID: assetID),
              tiles.count == 9 else {
            return
        }

        let tileWidth = CGFloat(tiles[0].width)
        let tileHeight = CGFloat(tiles[0].height)
        let middleWidth = max(0, rect.width - (tileWidth * 2))
        let middleHeight = max(0, rect.height - (tileHeight * 2))

        let drawRects = [
            CGRect(x: rect.minX, y: rect.minY, width: tileWidth, height: tileHeight),
            CGRect(x: rect.minX + tileWidth, y: rect.minY, width: middleWidth, height: tileHeight),
            CGRect(x: rect.maxX - tileWidth, y: rect.minY, width: tileWidth, height: tileHeight),
            CGRect(x: rect.minX, y: rect.minY + tileHeight, width: tileWidth, height: middleHeight),
            CGRect(x: rect.minX + tileWidth, y: rect.minY + tileHeight, width: middleWidth, height: middleHeight),
            CGRect(x: rect.maxX - tileWidth, y: rect.minY + tileHeight, width: tileWidth, height: middleHeight),
            CGRect(x: rect.minX, y: rect.maxY - tileHeight, width: tileWidth, height: tileHeight),
            CGRect(x: rect.minX + tileWidth, y: rect.maxY - tileHeight, width: middleWidth, height: tileHeight),
            CGRect(x: rect.maxX - tileWidth, y: rect.maxY - tileHeight, width: tileWidth, height: tileHeight),
        ]

        for (tile, drawRect) in zip(tiles, drawRects) {
            drawImage(tile, in: drawRect, context: context)
        }
    }

    private func drawImage(
        _ image: CGImage,
        in rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(
            image,
            in: CGRect(
                x: 0,
                y: 0,
                width: rect.width,
                height: rect.height
            )
        )
        context.restoreGState()
    }

    private func clip(
        maskState: CompositorScreenMaskState,
        in rect: CGRect,
        context: CGContext
    ) {
        switch maskState {
        case .full:
            return
        case let .rect(maskRect):
            context.addRect(maskRect)
            context.clip()
        case let .multiRect(rects):
            context.beginPath()
            rects.forEach { context.addRect($0) }
            context.clip()
        }
    }

    private func drawCircleWipeOverlay(
        _ state: CompositorCircleWipeOverlayState,
        in rect: CGRect,
        context: CGContext
    ) {
        let boundary = lineBoundaryPoints(
            in: rect,
            counter: state.counter,
            durationFrames: state.durationFrames
        )

        context.saveGState()
        context.beginPath()
        if state.coversInside == false {
            context.addRect(rect)
        }
        guard let firstBoundaryPoint = boundary.first else {
            context.restoreGState()
            return
        }
        context.move(to: CGPoint(x: rect.minX, y: rect.minY))
        context.addLine(to: firstBoundaryPoint)
        for point in boundary.dropFirst() {
            context.addLine(to: point)
        }
        context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        context.closePath()
        context.clip(using: state.coversInside ? .winding : .evenOdd)
        context.setFillColor(state.color.cgColor)
        context.fill(rect)
        context.restoreGState()
    }

    private func lineBoundaryPoints(
        in rect: CGRect,
        counter: Int,
        durationFrames: Int
    ) -> [CGPoint] {
        let clampedCounter = min(max(counter, 0), max(0, durationFrames - 1))
        let theta = Double.pi * Double(clampedCounter) / Double(max(1, durationFrames))
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

    private func hasProgramSurfaceContent(
        for screen: HGSSOpeningBundle.ScreenID,
        controller: HGSSOpeningPlaybackController
    ) -> Bool {
        let programScreen = programScreenID(for: screen)
        return controller.activeSolidFill(screen: programScreen) != nil
            || controller.activeMessageBox(screen: programScreen) != nil
            || controller.activeMenu(screen: programScreen) != nil
    }

    private func programScreenID(
        for screen: HGSSOpeningBundle.ScreenID
    ) -> HGSSOpeningProgramIR.ScreenID {
        switch screen {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
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

    private func overlayForScreen(
        _ screen: HGSSOpeningBundle.ScreenID,
        scene: HGSSOpeningBundle.Scene,
        frame: Int
    ) -> (color: NSColor, opacity: Double)? {
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
        return (nsColor(hex: relevantCue.colorHex ?? "#FFFFFF"), opacity)
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
    ) -> CompositorScreenMaskState {
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
    ) -> CompositorCircleWipeOverlayState? {
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
        return CompositorCircleWipeOverlayState(
            counter: counter,
            durationFrames: durationFrames,
            coversInside: mode == 0 || mode == 2,
            color: nsColor(hex: activeCue.colorHex ?? "#000000")
        )
    }

    private func menuContentHeight(
        _ menu: HGSSOpeningProgramIR.MenuCommand
    ) -> CGFloat {
        let optionHeights = menu.options.map { CGFloat($0.heightPixels ?? 32) }
        let spacing = CGFloat(menu.chrome?.optionSpacingPixels ?? 16)
        let totalOptionHeight = optionHeights.reduce(0, +)
        let totalSpacing = spacing * CGFloat(max(0, optionHeights.count - 1))
        let topInset = CGFloat(menu.chrome?.optionOrigin.y ?? 8)
        return topInset + totalOptionHeight + totalSpacing
    }

    private func menuScrollOffset(
        _ menu: HGSSOpeningProgramIR.MenuCommand,
        selectedOptionID: String
    ) -> CGFloat {
        guard let selectedIndex = menu.options.firstIndex(where: { $0.id == selectedOptionID }) else {
            return 0
        }

        let rect = self.rect(from: menuOptionRect(menu, index: selectedIndex, scrollOffset: 0))
        let viewportHeight: CGFloat = 192
        let bottomPadding: CGFloat = 8
        let rawOffset = rect.maxY - (viewportHeight - bottomPadding)
        let maxOffset = max(0, menuContentHeight(menu) - viewportHeight)
        return max(0, min(rawOffset, maxOffset))
    }

    private func menuOptionRect(
        _ menu: HGSSOpeningProgramIR.MenuCommand,
        index: Int,
        scrollOffset: CGFloat
    ) -> HGSSOpeningProgramIR.ScreenRect {
        let chrome = menu.chrome
        let originX = chrome?.optionOrigin.x ?? 24
        let originY = chrome?.optionOrigin.y ?? 8
        let width = chrome?.optionWidth ?? 184
        let spacing = chrome?.optionSpacingPixels ?? 16
        let y = menu.options.prefix(index).reduce(originY) { partial, option in
            partial + (option.heightPixels ?? 32) + spacing
        } - Int(scrollOffset.rounded(.towardZero))
        let height = menu.options[index].heightPixels ?? 32
        return .init(x: originX, y: y, width: width, height: height)
    }

    private func nineSliceTiles(assetID: String) -> [CGImage]? {
        guard let image = cgImage(forAssetID: assetID) else {
            return nil
        }

        let tileWidth = image.width / 3
        let tileHeight = image.height / 3
        guard tileWidth > 0, tileHeight > 0 else {
            return nil
        }

        var tiles: [CGImage] = []
        for row in 0..<3 {
            for column in 0..<3 {
                let cropRect = CGRect(
                    x: column * tileWidth,
                    y: image.height - ((row + 1) * tileHeight),
                    width: tileWidth,
                    height: tileHeight
                )
                guard let tile = image.cropping(to: cropRect.integral) else {
                    return nil
                }
                tiles.append(tile)
            }
        }
        return tiles
    }

    private func cropWifiIcon(assetID: String, type: Int) -> CGImage? {
        guard let image = cgImage(forAssetID: assetID) else {
            return nil
        }
        let iconWidth = image.width / 2
        let iconOriginX = type == 2 ? iconWidth : 0
        let cropRect = CGRect(x: iconOriginX, y: 0, width: iconWidth, height: image.height)
        return image.cropping(to: cropRect.integral)
    }

    private func glyphCGImage(
        text: String,
        style: HGSSDSGlyphTextStyle
    ) -> CGImage? {
        guard let image = try? HGSSDSGlyphRenderer.shared.renderImage(
            text: text,
            from: loadedBundle.rootURL,
            style: style
        ) else {
            return nil
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private func cgImage(forAssetID assetID: String) -> CGImage? {
        if let cached = imageCache[assetID] {
            return cached
        }
        guard let url = try? loadedBundle.assetURL(id: assetID),
              let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        imageCache[assetID] = cgImage
        return cgImage
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

    private func rect(from rect: HGSSOpeningBundle.ScreenRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    private func rect(from rect: HGSSOpeningProgramIR.ScreenRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
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

    private func nsColor(hex: String) -> NSColor {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

private enum CompositorScreenMaskState {
    case full
    case rect(CGRect)
    case multiRect([CGRect])
}

private struct CompositorCircleWipeOverlayState {
    let counter: Int
    let durationFrames: Int
    let coversInside: Bool
    let color: NSColor
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}
