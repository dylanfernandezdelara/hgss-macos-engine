import CoreGraphics
import Foundation

struct WindowMatch {
    var owner: String?
    var title: String?
}

@inline(__always)
func usage() -> Never {
    FileHandle.standardError.write(
        Data(
            """
            Usage: hgss_window_query.swift [--owner NAME] [--title TITLE] [--json] [--list]
            Prints the first matching on-screen window ID or lists visible windows.
            """.utf8
        )
    )
    exit(64)
}

func parseArguments() -> (WindowMatch, Bool, Bool) {
    var match = WindowMatch()
    var emitJSON = false
    var listWindows = false

    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--owner":
            guard let value = iterator.next(), !value.isEmpty else {
                usage()
            }
            match.owner = value
        case "--title":
            guard let value = iterator.next(), !value.isEmpty else {
                usage()
            }
            match.title = value
        case "--json":
            emitJSON = true
        case "--list":
            listWindows = true
        case "--help":
            usage()
        default:
            usage()
        }
    }

    return (match, emitJSON, listWindows)
}

func windowMatches(_ window: [String: Any], match: WindowMatch) -> Bool {
    if let owner = match.owner {
        let candidate = window[kCGWindowOwnerName as String] as? String ?? ""
        guard candidate == owner else {
            return false
        }
    }

    if let title = match.title {
        let candidate = window[kCGWindowName as String] as? String ?? ""
        guard candidate == title else {
            return false
        }
    }

    let layer = window[kCGWindowLayer as String] as? Int ?? 0
    let alpha = window[kCGWindowAlpha as String] as? Double ?? 1
    return layer == 0 && alpha > 0
}

func firstMatchingWindow(match: WindowMatch) -> [String: Any]? {
    let options: CGWindowListOption = [.optionAll]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }

    return list.first(where: { windowMatches($0, match: match) })
}

func listedWindows() -> [[String: Any]] {
    let options: CGWindowListOption = [.optionAll]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return []
    }
    return list
}

func encodeJSON(_ payload: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
}

let (match, emitJSON, listWindows) = parseArguments()

if listWindows {
    let payload = listedWindows().map { window in
        [
            "id": window[kCGWindowNumber as String] as? Int ?? 0,
            "owner": (window[kCGWindowOwnerName as String] as? String ?? "") as Any,
            "title": (window[kCGWindowName as String] as? String ?? "") as Any,
            "layer": (window[kCGWindowLayer as String] as? Int ?? 0) as Any,
            "alpha": (window[kCGWindowAlpha as String] as? Double ?? 0) as Any,
        ]
    }
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
    exit(0)
}

guard let window = firstMatchingWindow(match: match) else {
    exit(1)
}

let windowID = window[kCGWindowNumber as String] as? Int ?? 0
guard emitJSON else {
    print(windowID)
    exit(0)
}

let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
let payload: [String: Any] = [
    "id": windowID,
    "owner": window[kCGWindowOwnerName as String] as? String ?? "",
    "title": window[kCGWindowName as String] as? String ?? "",
    "layer": window[kCGWindowLayer as String] as? Int ?? 0,
    "bounds": bounds,
]

let data = try encodeJSON(payload)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data([0x0A]))
