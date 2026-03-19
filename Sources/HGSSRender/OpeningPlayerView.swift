import AppKit
import Foundation
import HGSSDataModel
import HGSSOpeningIR
import SwiftUI

public struct HGSSOpeningPlayerView: View {
    private enum NativeMetrics {
        static let screenGap: CGFloat = 18
    }

    @ObservedObject private var controller: HGSSOpeningPlaybackController
    private let loadedBundle: LoadedOpeningBundle
    private let compositor: HGSSOpeningScreenCompositor
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
        self.compositor = HGSSOpeningScreenCompositor(loadedBundle: loadedBundle)
        self.showDebugOverlay = showDebugOverlay
        self.onBottomScreenTap = onBottomScreenTap
    }

    public var body: some View {
        let topScreen = loadedBundle.bundle.topScreen
        let bottomScreen = loadedBundle.bundle.bottomScreen

        VStack(spacing: NativeMetrics.screenGap) {
            openingScreenView(screen: .top, size: topScreen)
                .frame(width: CGFloat(topScreen.width), height: CGFloat(topScreen.height))

            openingScreenView(screen: .bottom, size: bottomScreen)
                .frame(width: CGFloat(bottomScreen.width), height: CGFloat(bottomScreen.height))
                .contentShape(Rectangle())
                .onTapGesture {
                    onBottomScreenTap()
                }
        }
        .frame(
            width: CGFloat(topScreen.width),
            height: CGFloat(topScreen.height + bottomScreen.height) + NativeMetrics.screenGap,
            alignment: .top
        )
        .background(Color.black)
    }

    @ViewBuilder
    private func openingScreenView(
        screen: HGSSOpeningBundle.ScreenID,
        size: HGSSOpeningBundle.NativeScreen
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if let renderedImage = compositor.renderCGImage(
                screen: screen,
                size: size,
                controller: controller
            ) {
                Image(decorative: renderedImage, scale: 1, orientation: .up)
                    .interpolation(.none)
                    .frame(width: CGFloat(size.width), height: CGFloat(size.height), alignment: .topLeading)
            } else {
                Color.black
                    .frame(width: CGFloat(size.width), height: CGFloat(size.height), alignment: .topLeading)
            }

            if showDebugOverlay {
                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.currentProgramScene?.id.rawValue ?? controller.currentScene.id.rawValue)
                    Text("frame \(controller.state.frameInScene)/\(controller.currentScene.durationFrames - 1)")
                    if let programState = controller.currentProgramState {
                        Text("\(programState.id) @ \(controller.state.frameInProgramState)")
                    }
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .padding(8)
                .foregroundStyle(.white)
                .background(Color.black.opacity(0.45))
            }
        }
        .background(Color.black)
        .clipped()
    }

    private func hasProgramSurfaceContent(for screen: HGSSOpeningBundle.ScreenID) -> Bool {
        let programScreen = programScreenID(for: screen)
        return controller.activeSolidFill(screen: programScreen) != nil
            || controller.activeMessageBox(screen: programScreen) != nil
            || controller.activeMenu(screen: programScreen) != nil
    }

    private func programPromptView(
        _ prompt: HGSSOpeningProgramIR.PromptFlashCommand
    ) -> some View {
        let rect = prompt.rect ?? .init(x: 0, y: 144, width: 256, height: 16)
        let promptText = prompt.text ?? "TOUCH TO START"
        return glyphTextView(
            promptText,
            style: .init(
                foregroundPaletteIndex: 1,
                shadowPaletteIndex: 1,
                backgroundPaletteIndex: 0,
                letterSpacing: prompt.letterSpacing
            ),
            fallback: {
                Text(promptText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(red: 0.86, green: 0.55, blue: 0.09))
            }
        )
            .frame(width: CGFloat(rect.width), height: CGFloat(rect.height))
            .position(
                x: CGFloat(rect.x) + (CGFloat(rect.width) / 2.0),
                y: CGFloat(rect.y) + (CGFloat(rect.height) / 2.0)
            )
    }

    @ViewBuilder
    private func postTitleProgramScreenView(
        screen: HGSSOpeningBundle.ScreenID,
        size: HGSSOpeningBundle.NativeScreen
    ) -> some View {
        let programScreen = programScreenID(for: screen)
        let fill = controller.activeSolidFill(screen: programScreen)
        let messageBox = controller.activeMessageBox(screen: programScreen)
        let menu = controller.activeMenu(screen: programScreen)
        let programFadeOverlay = controller.activeProgramFadeOverlay()
        let programGlowOverlay = controller.activeProgramGlowOverlay(screen: programScreen)

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(hex: fill?.colorHex ?? "#000000"))
                .frame(width: CGFloat(size.width), height: CGFloat(size.height))

            if let messageBox {
                programMessageBoxView(messageBox)
            }

            if let menu {
                programMenuView(
                    menu,
                    selectedOptionID: controller.resolvedMenuSelectionID(for: menu)
                )
            }

            if let programGlowOverlay {
                Rectangle()
                    .fill(Color(hex: programGlowOverlay.colorHex).opacity(programGlowOverlay.opacity))
                    .frame(width: CGFloat(size.width), height: CGFloat(size.height))
            }

            if let programFadeOverlay {
                Rectangle()
                    .fill(Color(hex: programFadeOverlay.colorHex).opacity(programFadeOverlay.opacity))
                    .frame(width: CGFloat(size.width), height: CGFloat(size.height))
            }

            if showDebugOverlay {
                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.currentProgramScene?.id.rawValue ?? "post_title")
                    Text(controller.currentProgramState?.id ?? "<none>")
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

    @ViewBuilder
    private func programMessageBoxView(
        _ messageBox: HGSSOpeningProgramIR.MessageBoxCommand
    ) -> some View {
        let rect = messageBox.rect
        let insets = messageBox.textInsets ?? .init(top: 4, left: 6, bottom: 4, right: 6)
        let text = messageBox.text.replacingOccurrences(of: "\\n", with: "\n")

        ZStack(alignment: .topLeading) {
            if let frameAssetID = messageBox.frameAssetID {
                framedSurfaceView(
                    assetID: frameAssetID,
                    size: CGSize(width: rect.width, height: rect.height)
                )
                .position(
                    x: CGFloat(rect.x) + (CGFloat(rect.width) / 2.0),
                    y: CGFloat(rect.y) + (CGFloat(rect.height) / 2.0)
                )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.08, green: 0.09, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.85), lineWidth: 2)
                    )
                    .frame(width: CGFloat(rect.width), height: CGFloat(rect.height))
                    .position(
                        x: CGFloat(rect.x) + (CGFloat(rect.width) / 2.0),
                        y: CGFloat(rect.y) + (CGFloat(rect.height) / 2.0)
                    )
            }

            glyphTextView(
                text,
                style: .body,
                fallback: {
                    Text(text)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            )
            .frame(
                width: CGFloat(rect.width - insets.left - insets.right),
                height: CGFloat(rect.height - insets.top - insets.bottom),
                alignment: .topLeading
            )
            .position(
                x: CGFloat(rect.x + insets.left) + (CGFloat(rect.width - insets.left - insets.right) / 2.0),
                y: CGFloat(rect.y + insets.top) + (CGFloat(rect.height - insets.top - insets.bottom) / 2.0)
            )
        }
    }

    @ViewBuilder
    private func programMenuView(
        _ menu: HGSSOpeningProgramIR.MenuCommand,
        selectedOptionID: String
    ) -> some View {
        if let chrome = menu.chrome {
            let scrollOffset = menuScrollOffset(menu, selectedOptionID: selectedOptionID)
            ZStack(alignment: .topLeading) {
                ForEach(Array(menu.options.enumerated()), id: \.element.id) { index, option in
                    let rect = menuOptionRect(menu, index: index, scrollOffset: scrollOffset)
                    let isSelected = option.id == selectedOptionID
                    let frameAssetID = isSelected
                        ? (chrome.selectedFrameAssetID ?? chrome.normalFrameAssetID)
                        : chrome.normalFrameAssetID

                    if let frameAssetID {
                        framedSurfaceView(
                            assetID: frameAssetID,
                            size: CGSize(width: rect.width, height: rect.height)
                        )
                        .position(
                            x: CGFloat(rect.x) + (CGFloat(rect.width) / 2.0),
                            y: CGFloat(rect.y) + (CGFloat(rect.height) / 2.0)
                        )
                    }

                    if let wirelessIconType = option.wirelessIconType,
                       let wifiIconSheetAssetID = chrome.wifiIconSheetAssetID {
                        wifiIconView(
                            assetID: wifiIconSheetAssetID,
                            type: wirelessIconType
                        )
                        .frame(width: 16, height: 16)
                        .position(
                            x: CGFloat(rect.x + rect.width - 8),
                            y: CGFloat(rect.y + 8)
                        )
                    }

                    glyphTextView(
                        option.text.replacingOccurrences(of: "\\n", with: "\n"),
                        style: .body,
                        fallback: {
                            Text(option.text.replacingOccurrences(of: "\\n", with: "\n"))
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    )
                    .frame(
                        width: CGFloat(max(0, rect.width - 40)),
                        height: CGFloat(max(0, rect.height - 8)),
                        alignment: .topLeading
                    )
                    .position(
                        x: CGFloat(rect.x + 20) + (CGFloat(max(0, rect.width - 40)) / 2.0),
                        y: CGFloat(rect.y + 4) + (CGFloat(max(0, rect.height - 8)) / 2.0)
                    )
                    .opacity(option.enabled ? 1.0 : 0.6)
                }

                if let upArrowRect = chrome.upArrowRect,
                   chrome.upArrowFrameAssetIDs.isEmpty == false,
                   scrollOffset > 0 {
                    arrowAnimationView(frameAssetIDs: chrome.upArrowFrameAssetIDs)
                        .frame(width: CGFloat(upArrowRect.width), height: CGFloat(upArrowRect.height))
                        .position(
                            x: CGFloat(upArrowRect.x) + (CGFloat(upArrowRect.width) / 2.0),
                            y: CGFloat(upArrowRect.y) + (CGFloat(upArrowRect.height) / 2.0)
                        )
                }

                if let downArrowRect = chrome.downArrowRect,
                   chrome.downArrowFrameAssetIDs.isEmpty == false,
                   menuContentHeight(menu) - scrollOffset > 192 {
                    arrowAnimationView(frameAssetIDs: chrome.downArrowFrameAssetIDs)
                        .frame(width: CGFloat(downArrowRect.width), height: CGFloat(downArrowRect.height))
                        .position(
                            x: CGFloat(downArrowRect.x) + (CGFloat(downArrowRect.width) / 2.0),
                            y: CGFloat(downArrowRect.y) + (CGFloat(downArrowRect.height) / 2.0)
                        )
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(menu.options, id: \.id) { option in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(option.id == selectedOptionID ? Color(red: 0.96, green: 0.79, blue: 0.12) : Color.clear)
                            .frame(width: 8, height: 8)
                        glyphTextView(
                            option.text.replacingOccurrences(of: "\\n", with: "\n"),
                            style: .body,
                            fallback: {
                                Text(option.text.replacingOccurrences(of: "\\n", with: "\n"))
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(option.id == selectedOptionID ? Color.white : Color.white.opacity(0.7))
                            }
                        )
                        .opacity(option.id == selectedOptionID ? 1.0 : 0.78)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
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

    @ViewBuilder
    private func glyphTextView<Fallback: View>(
        _ text: String,
        style: HGSSDSGlyphTextStyle,
        @ViewBuilder fallback: () -> Fallback
    ) -> some View {
        if let image = try? HGSSDSGlyphRenderer.shared.renderImage(
            text: text,
            from: loadedBundle.rootURL,
            style: style
        ) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: image.size.width, height: image.size.height, alignment: .topLeading)
        } else {
            fallback()
        }
    }

    @ViewBuilder
    private func framedSurfaceView(
        assetID: String,
        size: CGSize
    ) -> some View {
        if let tiles = nineSliceTiles(assetID: assetID),
           tiles.count == 9 {
            let tileHeight = tiles[0].size.height
            let middleHeight = max(0, size.height - (tileHeight * 2))

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Image(nsImage: tiles[0]).interpolation(.none)
                    Image(nsImage: tiles[1]).resizable(resizingMode: .tile).interpolation(.none)
                    Image(nsImage: tiles[2]).interpolation(.none)
                }
                .frame(width: size.width, height: tileHeight, alignment: .topLeading)

                HStack(spacing: 0) {
                    Image(nsImage: tiles[3]).resizable(resizingMode: .tile).interpolation(.none)
                    Image(nsImage: tiles[4]).resizable(resizingMode: .tile).interpolation(.none)
                    Image(nsImage: tiles[5]).resizable(resizingMode: .tile).interpolation(.none)
                }
                .frame(width: size.width, height: middleHeight, alignment: .topLeading)

                HStack(spacing: 0) {
                    Image(nsImage: tiles[6]).interpolation(.none)
                    Image(nsImage: tiles[7]).resizable(resizingMode: .tile).interpolation(.none)
                    Image(nsImage: tiles[8]).interpolation(.none)
                }
                .frame(width: size.width, height: tileHeight, alignment: .topLeading)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        } else {
            Color.clear
                .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private func wifiIconView(
        assetID: String,
        type: Int
    ) -> some View {
        if let image = try? loadedBundle.assetURL(id: assetID).image,
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let iconWidth = cgImage.width / 2
            let iconOriginX = type == 2 ? iconWidth : 0
            let cropRect = CGRect(x: iconOriginX, y: 0, width: iconWidth, height: cgImage.height)
            if let icon = croppedImage(from: cgImage, rect: cropRect) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.none)
            } else {
                Color.clear
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func arrowAnimationView(frameAssetIDs: [String]) -> some View {
        let frameIndex = frameAssetIDs.isEmpty ? 0 : (controller.state.frameInProgramState / 4) % frameAssetIDs.count
        if frameAssetIDs.indices.contains(frameIndex),
           let image = try? loadedBundle.assetURL(id: frameAssetIDs[frameIndex]).image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
        } else {
            Color.clear
        }
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

        let rect = menuOptionRect(menu, index: selectedIndex, scrollOffset: 0)
        let viewportHeight: CGFloat = 192
        let bottomPadding: CGFloat = 8
        let rawOffset = CGFloat(rect.y + rect.height) - (viewportHeight - bottomPadding)
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

    private func nineSliceTiles(assetID: String) -> [NSImage]? {
        guard let image = try? loadedBundle.assetURL(id: assetID).image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let tileWidth = cgImage.width / 3
        let tileHeight = cgImage.height / 3
        guard tileWidth > 0, tileHeight > 0 else {
            return nil
        }

        var tiles: [NSImage] = []
        for row in 0..<3 {
            for column in 0..<3 {
                let cropRect = CGRect(
                    x: column * tileWidth,
                    y: cgImage.height - ((row + 1) * tileHeight),
                    width: tileWidth,
                    height: tileHeight
                )
                guard let tile = croppedImage(from: cgImage, rect: cropRect) else {
                    return nil
                }
                tiles.append(tile)
            }
        }

        return tiles
    }

    private func croppedImage(
        from cgImage: CGImage,
        rect: CGRect
    ) -> NSImage? {
        guard let cropped = cgImage.cropping(to: rect.integral) else {
            return nil
        }
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
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
