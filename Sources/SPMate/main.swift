#if canImport(PamphletFramework)

import PamphletFramework
import ArgumentParser
import Foundation

struct SPMate: ParsableCommand {
    
    static var configuration = CommandConfiguration(
        abstract: "Store files resources in Swift code",
        subcommands: [Tests.self],
        defaultSubcommand: Tests.self)
    
    struct Tests: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Perform actions related to testing")
                
        mutating func run() throws {
            
        }
    }
}

SPMate.main()

#endif
