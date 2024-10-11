import ArgumentParser
import Foundation
import SPMateFramework
import Flynn

struct SPMate: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Interact with Swift Package Manager",
        subcommands: [Test.self],
        defaultSubcommand: Test.self)
}

struct Options: ParsableArguments {
    @Argument(help: "Path to Swift project directory")
    var path: String?
}

extension SPMate {
    struct Test: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Interact with Swift testing",
            subcommands: [List.self]
        )
    }
    
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all available tests"
        )
        
        @OptionGroup var options: Options
        
        mutating func run() throws {
            let project = SwiftProject(path: options.path ?? FileManager.default.currentDirectoryPath)
            project.beTestsList(Flynn.any) { tests in
                print(tests)
            }
            Flynn.shutdown()
        }
    }
}

SPMate.main()
