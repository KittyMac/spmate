import Flynn
import SourceKittenFramework
import Foundation
import Hitch
import Studding

public class TestFunction: Codable {
    public var targetName: String
    public var className: String
    public var functionName: String
    public var filePath: String?
    public var fileOffset: Int64?
    
    init(targetName: String,
         className: String,
         functionName: String,
         filePath: String?,
         fileOffset: Int64?) {
        self.targetName = targetName
        self.className = className
        self.functionName = functionName
        self.filePath = filePath
        self.fileOffset = fileOffset
    }
}

public class TestResult: Codable {
    public var targetName: String
    public var className: String
    public var functionName: String
    public var result: String
    
    init(targetName: String,
         className: String,
         functionName: String,
         result: String) {
        self.targetName = targetName
        self.className = className
        self.functionName = functionName
        self.result = result
    }
}

extension SwiftProject {
    internal func _beTestsList(_ returnCallback: ([TestFunction]) -> ()) {
        let astBuilder = ASTBuilder()
        astBuilder.add(directory: safePath + "/Tests")
                
        let ast = astBuilder.build()
        
        // TODO: parse the Package.swift and only include tests from testing targets (also know the target name)
        
        // Find all classes which descend from XCTestCase
        var allTests: [TestFunction] = []
        
        for (className, classSyntax) in ast.classes {
            if ast.isSubclassOf(classSyntax, "XCTestCase") {
                                
                // find all functions which start with test
                if let functions = classSyntax.structure.substructure {
                    for function in functions {
                        if let functionName = function.name,
                           functionName.hasPrefix("test"),
                           function.kind == .functionMethodInstance {
                            
                            // functionName(argument:)
                            // we only want the base name
                            let regex = #"^([\d\w]+)\("#
                            functionName.matches(regex) { (_, groups) in
                                guard groups.count == 2 else { return }
                                allTests.append(
                                    TestFunction(targetName: "",
                                                 className: className,
                                                 functionName: groups[1],
                                                 filePath: classSyntax.file.path,
                                                 fileOffset: function.bodyoffset)
                                )
                            }
                        }
                    }
                }
            }
        }
        
        returnCallback(allTests)
    }
    
    internal func _beTestsRun(filters: [String]?,
                              _ returnCallback: @escaping ([TestResult]) -> ()) {
        
        // options for improving speed:
        // prebuild: swift build --build-tests
        //
        // Use multiple processes ourselve (don't use --parallel); perhaps one
        // process for each testing class?
        // swift test --skip-build --filter test_a
        
        // NOT IDEAL
        // call xctest directly like this
        // /Applications/Xcode-15.2.0.app/Contents/Developer/usr/bin/xctest -XCTest EMLTests_AC.ReceiptsTests_cabelas0/test_cabelas00 /Users/rjbowli/Development/smallplanet/smallplanet_RoverJS_SDK/eml_tests/.build/arm64-apple-macosx/debug/MerchantPackageTests.xctest
        // /Applications/Xcode-15.2.0.app/Contents/Developer/usr/bin/xctest -XCTest --dump-tests-json /Users/rjbowli/Development/smallplanet/smallplanet_RoverJS_SDK/eml_tests/.build/arm64-apple-macosx/debug/MerchantPackageTests.xctest
        
        let path = pathFor(executable: "swift")
        let projectPath = safePath
        
        
        // 0. ensure the swift project is built for testing
        //let startBuilds = Date()
        var arguments: [String] = []
        arguments.append("build")
        arguments.append("--package-path")
        arguments.append(safePath)
        arguments.append("--build-tests")
        let task = Spawn(path: path,
                         arguments: arguments)
        task.nullStandardOutput()
        task.nullStandardError()
        task.run()
        task.wait()
        // print("Build done in \(abs(startBuilds.timeIntervalSinceNow))s")
        
        // 1. then run all of the filters in parallel
        let allFilters = filters ?? [""]
        var allResults: [TestResult] = []
        //let startTests = Date()
        
        allFilters.syncOOB(timeout: 30 * 60) { filter, synchronized in
                    
            var arguments: [String] = []
            arguments.append("test")
            arguments.append("--skip-build")
            arguments.append("--package-path")
            arguments.append(projectPath)
            if filter.isEmpty == false {
                arguments.append("--filter")
                arguments.append(filter)
            }
            let outPipe = SafePipe()!
            let task = Spawn(path: path,
                             arguments: arguments)
            task.setStandardOutput(outPipe)
            task.nullStandardError()
            
            task.terminationHandler = { _, _ in
                outPipe.fileHandleForWriting.closeFile()
            }

            task.run()
            
            Thread {
                while let result = outPipe.fileHandleForReading.read(upToCount: 1024 * 1024 * 32) {
                    let hitch = Hitch(data: result)
                    let lines: [HalfHitch] = hitch.components(separatedBy: "\n")
                    for line in lines {
                        // Test Case '-[testTests.ExampleTestsA testExample0]' passed (0.001 seconds).
                        // Test Case '-[testTests.ExampleTestsB testExample1]' failed (0.000 seconds).
                        let regex = #"\[([\w\d]+)\.([\w\d]+)\s([\w\d]+)]\'\s+(\w+)"#
                        
                        if line.starts(with: "Test Case ") {
                            line.toTempString().matches(regex) { (_, groups) in
                                guard groups.count == 5 else { return }
                                
                                let targetName = groups[1]
                                let className = groups[2]
                                let functionName = groups[3]
                                let result = groups[4]
                                
                                if result == "passed" || result == "failed" {
                                    synchronized {
                                        allResults.append(
                                            TestResult(targetName: targetName,
                                                       className: className,
                                                       functionName: functionName,
                                                       result: result)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }.start()
            
            task.wait()
        }
        
        // print("All tests done in \(abs(startTests.timeIntervalSinceNow))s")
        
        returnCallback(allResults)
    }
}
