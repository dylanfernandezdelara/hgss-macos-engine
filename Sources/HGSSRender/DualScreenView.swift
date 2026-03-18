import AppKit
import Foundation
import HGSSCore
import HGSSDataModel
import SwiftUI

public struct HGSSDualScreenView: View {
    private let loadedBundle: LoadedRenderBundle
    private let presentation: HGSSDualScreenPresentation

    public init(loadedBundle: LoadedRenderBundle, presentation: HGSSDualScreenPresentation) {
        self.loadedBundle = loadedBundle
        self.presentation = presentation
    }

    public var body: some View {
        GeometryReader { geometry in
            let topScreen = loadedBundle.bundle.topScreen.nativeScreen
            let bottomScreen = loadedBundle.bundle.bottomScreen.nativeScreen
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
                HGSSTopScreenView(
                    loadedBundle: loadedBundle,
                    presentation: presentation
                )
                .frame(width: CGFloat(topScreen.width), height: CGFloat(topScreen.height))

                HGSSBottomScreenView(
                    loadedBundle: loadedBundle,
                    presentation: presentation
                )
                    .frame(width: CGFloat(bottomScreen.width), height: CGFloat(bottomScreen.height))
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
                        Color(hex: "#07090B"),
                        Color(hex: "#11161D"),
                        Color(hex: "#1A2028")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

private struct HGSSTopScreenView: View {
    let loadedBundle: LoadedRenderBundle
    let presentation: HGSSDualScreenPresentation

    var body: some View {
        let topScreen = loadedBundle.bundle.topScreen

        ZStack(alignment: .topLeading) {
            RenderAssetImageView(
                loadedBundle: loadedBundle,
                assetID: topScreen.frameAssetID,
                width: topScreen.nativeScreen.width,
                height: topScreen.nativeScreen.height
            )

            if presentation.showDeveloperOverlay {
                HGSSDeveloperOverlayView(
                    loadedBundle: loadedBundle,
                    presentation: presentation
                )
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.black.opacity(0.92), lineWidth: 4)
        )
        .background(Color.black)
        .clipped()
    }
}

private struct HGSSBottomScreenView: View {
    let loadedBundle: LoadedRenderBundle
    let presentation: HGSSDualScreenPresentation

    var body: some View {
        let bottomScreen = loadedBundle.bundle.bottomScreen

        RenderAssetImageView(
            loadedBundle: loadedBundle,
            assetID: bottomScreen.frameAssetID,
            width: bottomScreen.nativeScreen.width,
            height: bottomScreen.nativeScreen.height
        )
        .overlay(
            Rectangle()
                .stroke(Color.black.opacity(0.92), lineWidth: 4)
        )
        .background(Color.black)
        .clipped()
    }
}

private struct RenderAssetImageView: View {
    let loadedBundle: LoadedRenderBundle
    let assetID: String
    let width: Int
    let height: Int

    var body: some View {
        Group {
            if let image = try? loadedBundle.assetURL(id: assetID).image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
            } else {
                Color.black
            }
        }
        .frame(width: CGFloat(width), height: CGFloat(height))
    }
}

private struct HGSSDeveloperOverlayView: View {
    let loadedBundle: LoadedRenderBundle
    let presentation: HGSSDualScreenPresentation

    var body: some View {
        let palette = loadedBundle.bundle.developerOverlay.palette
        let camera = loadedBundle.bundle.topScreen.camera
        let tileSize = CGFloat(camera.tileSize)

        ZStack(alignment: .topLeading) {
            overlayTiles(
                from: presentation.snapshot.blockedTiles,
                fillHex: palette.blockedFillHex,
                strokeHex: palette.blockedStrokeHex,
                tileSize: tileSize
            )

            overlayTiles(
                from: presentation.snapshot.warpTiles,
                fillHex: palette.warpFillHex,
                strokeHex: palette.warpStrokeHex,
                tileSize: tileSize
            )

            overlayTiles(
                from: presentation.snapshot.placementTiles,
                fillHex: palette.placementFillHex,
                strokeHex: palette.placementStrokeHex,
                tileSize: tileSize
            )

            overlayTiles(
                from: presentation.snapshot.entryPointTiles,
                fillHex: palette.entryPointFillHex,
                strokeHex: palette.entryPointStrokeHex,
                tileSize: tileSize
            )

            HGSSGridOverlayView(
                snapshot: presentation.snapshot,
                cameraOrigin: presentation.cameraOrigin,
                viewportTilesWide: camera.viewportTilesWide,
                viewportTilesHigh: camera.viewportTilesHigh,
                tileSize: tileSize,
                stroke: Color(hex: palette.gridHex)
            )

            overlayLegend(palette: palette)
                .padding(8)
        }
    }

    @ViewBuilder
    private func overlayTiles(
        from tiles: Set<TilePosition>,
        fillHex: String,
        strokeHex: String,
        tileSize: CGFloat
    ) -> some View {
        ForEach(visibleTiles(from: tiles), id: \.self) { tile in
            let frame = tileFrame(for: tile, tileSize: tileSize)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: fillHex).opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: strokeHex), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                )
                .frame(width: frame.width - 4, height: frame.height - 4)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    private func visibleTiles(from tiles: Set<TilePosition>) -> [TilePosition] {
        let originX = presentation.cameraOrigin.x
        let originY = presentation.cameraOrigin.y
        let maxX = originX + Double(loadedBundle.bundle.topScreen.camera.viewportTilesWide)
        let maxY = originY + Double(loadedBundle.bundle.topScreen.camera.viewportTilesHigh)

        return tiles
            .filter { tile in
                Double(tile.x) >= originX &&
                Double(tile.x) < maxX &&
                Double(tile.y) >= originY &&
                Double(tile.y) < maxY
            }
            .sorted { lhs, rhs in
                lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y
            }
    }

    private func tileFrame(for tile: TilePosition, tileSize: CGFloat) -> CGRect {
        let x = (CGFloat(tile.x) - CGFloat(presentation.cameraOrigin.x)) * tileSize
        let y = (CGFloat(tile.y) - CGFloat(presentation.cameraOrigin.y)) * tileSize
        return CGRect(x: x, y: y, width: tileSize, height: tileSize)
    }

    private func overlayLegend(palette: HGSSRenderBundle.OverlayPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            legendRow("Blocked", fillHex: palette.blockedFillHex, strokeHex: palette.blockedStrokeHex)
            legendRow("Warp", fillHex: palette.warpFillHex, strokeHex: palette.warpStrokeHex)
            legendRow("Placement", fillHex: palette.placementFillHex, strokeHex: palette.placementStrokeHex)
            legendRow("Entry", fillHex: palette.entryPointFillHex, strokeHex: palette.entryPointStrokeHex)
        }
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 6))
    }

    private func legendRow(_ label: String, fillHex: String, strokeHex: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: fillHex).opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(hex: strokeHex), lineWidth: 1.5)
                )
                .frame(width: 12, height: 8)
            Text(label)
        }
    }
}

private struct HGSSGridOverlayView: View {
    let snapshot: CoreSnapshot
    let cameraOrigin: HGSSRenderDisplayPoint
    let viewportTilesWide: Int
    let viewportTilesHigh: Int
    let tileSize: CGFloat
    let stroke: Color

    var body: some View {
        Path { path in
            for x in 0...viewportTilesWide {
                let position = CGFloat(x) * tileSize
                path.move(to: CGPoint(x: position, y: 0))
                path.addLine(to: CGPoint(x: position, y: CGFloat(viewportTilesHigh) * tileSize))
            }

            for y in 0...viewportTilesHigh {
                let position = CGFloat(y) * tileSize
                path.move(to: CGPoint(x: 0, y: position))
                path.addLine(to: CGPoint(x: CGFloat(viewportTilesWide) * tileSize, y: position))
            }
        }
        .stroke(stroke.opacity(0.45), lineWidth: 1)
    }
}

private extension URL {
    var image: NSImage? {
        NSImage(contentsOf: self)
    }
}

private extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            self = Color(red: 1.0, green: 0.0, blue: 1.0)
            return
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self = Color(red: red, green: green, blue: blue)
    }
}
