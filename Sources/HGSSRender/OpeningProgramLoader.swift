import Foundation
import HGSSOpeningIR

public struct OpeningProgramLoader {
    public init() {}

    public func load(from rootURL: URL) throws -> LoadedOpeningProgram {
        let programURL = rootURL.appendingPathComponent("opening_program_ir.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: programURL.path()) else {
            throw HGSSRenderError.openingProgramMissing(path: programURL.path())
        }

        let data = try Data(contentsOf: programURL)
        let program: HGSSOpeningProgramIR
        do {
            program = try JSONDecoder().decode(HGSSOpeningProgramIR.self, from: data)
        } catch {
            throw HGSSRenderError.openingProgramDecodeFailed(underlying: error)
        }

        try program.validate()
        return LoadedOpeningProgram(rootURL: rootURL, program: program)
    }
}
