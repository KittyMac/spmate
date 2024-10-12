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
            subcommands: [List.self, Run.self]
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
                let json = try! tests.json(pretty: false)
                print(json)
            }
            Flynn.shutdown()
        }
    }
    
    struct Run: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Run "
        )
        
        @OptionGroup var options: Options
        
        @Option(help: "Run test cases matching regular expression")
        var filter: String?
        
        mutating func run() throws {
            let project = SwiftProject(path: options.path ?? FileManager.default.currentDirectoryPath)
            project.beTestsRun(filter: filter,
                               Flynn.any) { tests in
                let json = try! tests.json(pretty: false)
                print(json)
            }
            Flynn.shutdown()
        }
    }
}

SPMate.main()
