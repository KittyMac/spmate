import Flynn
import SourceKittenFramework
import Foundation
import Hitch

public class TestFunction: Codable {
    public var functionName: String
    public var filePath: String?
    public var fileOffset: Int64?
    
    init(functionName: String,
         filePath: String?,
         fileOffset: Int64?) {
        self.functionName = functionName
        self.filePath = filePath
        self.fileOffset = fileOffset
    }
}

public class TestClass: Codable {
    public var className: String
    public var tests: [TestFunction] = []
    
    init(className: String) {
        self.className = className
    }
}

public class TestResult: Codable {
    public var className: String
    public var functionName: String
    public var result: String
    
    init(className: String,
         functionName: String,
         result: String) {
        self.className = className
        self.functionName = functionName
        self.result = result
    }
}

extension SwiftProject {
    internal func _beTestsList(_ returnCallback: ([TestClass]) -> ()) {
        let astBuilder = ASTBuilder()
        astBuilder.add(directory: safePath + "/Tests")
                
        let ast = astBuilder.build()
        
        // Find all classes which descend from XCTestCase
        var allTestClasses: [TestClass] = []
        
        for (className, classSyntax) in ast.classes {
            if ast.isSubclassOf(classSyntax, "XCTestCase") {
                
                let testClass = TestClass(className: className)
                allTestClasses.append(testClass)
                
                // find all functions which start with test
                if let functions = classSyntax.structure.substructure {
                    for function in functions {
                        if let functionName = function.name,
                           functionName.hasPrefix("test"),
                           function.kind == .functionMethodInstance {
                            testClass.tests.append(
                                TestFunction(functionName: functionName,
                                             filePath: classSyntax.file.path,
                                             fileOffset: function.bodyoffset)
                            )
                        }
                    }
                }
            }
        }
        
        returnCallback(allTestClasses)
    }
    
    internal func _beTestsRun(filter: String?,
                              _ returnCallback: @escaping ([TestResult]) -> ()) {
        let path = pathFor(executable: "swift")
                
        var arguments: [String] = []
        arguments.append("test")
        arguments.append("--package-path")
        arguments.append(safePath)
        if let filter = filter {
            arguments.append("--filter")
            arguments.append(filter)
        }
        
        let outPipe = SafePipe()!
        let errPipe = SafePipe()!
                
        let task = Spawn(path: path,
                         arguments: arguments)
        
        task.setStandardOutput(outPipe)
        task.setStandardError(errPipe)
        
        task.terminationHandler = { _, _ in
            outPipe.fileHandleForWriting.closeFile()
            errPipe.fileHandleForReading.closeFile()
        }
        
        task.run()
        
        let actor = Actor()
        actor.unsafeSend { _ in
            
            var allResults: [TestResult] = []
            
            while true {
                guard let result = outPipe.fileHandleForReading.read(upToCount: 1024 * 1024 * 32) else {
                    break
                }
                
                let hitch = Hitch(data: result)
                let lines: [HalfHitch] = hitch.components(separatedBy: "\n")
                for line in lines {
                    // Test Case '-[testTests.ExampleTestsA testExample0]' passed (0.001 seconds).
                    // Test Case '-[testTests.ExampleTestsB testExample1]' failed (0.000 seconds).
                    let regex = #"\[[\w\d]+\.([\w\d]+)\s([\w\d]+)]\'\s+(\w+)"#
                    
                    if line.starts(with: "Test Case ") {
                        line.toTempString().matches(regex) { (_, groups) in
                            guard groups.count == 4 else { return }
                            
                            let className = groups[1]
                            let functionName = groups[2]
                            let result = groups[3]
                            
                            if result == "passed" || result == "failed" {
                                allResults.append(
                                    TestResult(className: className,
                                               functionName: functionName,
                                               result: result)
                                )
                            }
                        }
                    }
                }
                
                //print(Hitch(data: result))
            }
            
            returnCallback(allResults)
        }
        
        task.wait()
    }
}
