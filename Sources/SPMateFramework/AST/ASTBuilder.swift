import Foundation
import SourceKittenFramework

typealias ASTBuilderResult = ((AST) -> Void)

struct ASTBuilderIterator: IteratorProtocol {
    private var combinedArray: [FileSyntax]
    private var index = -1

    init(_ astBuilder: ASTBuilder) {
        combinedArray = []
        combinedArray.append(contentsOf: Array(astBuilder.classes.values))
        combinedArray.append(contentsOf: Array(astBuilder.protocols.values))
        combinedArray.append(contentsOf: astBuilder.extensions)
        combinedArray.append(contentsOf: astBuilder.calls)
        combinedArray.append(contentsOf: astBuilder.functions)
    }

    mutating func next() -> FileSyntax? {
        index += 1
        if index >= combinedArray.count {
            return nil
        }
        return combinedArray[index]
    }
}

class ASTBuilder: Sequence {
    var classes: [String: FileSyntax] = [:]
    var protocols: [String: FileSyntax] = [:]
    var extensions: [FileSyntax] = []
    var calls: [FileSyntax] = []
    var functions: [FileSyntax] = []
    var files: [FileSyntax] = []

    func add(_ fileSyntax: FileSyntax) {
        files.append(fileSyntax)
        recursiveAdd([], fileSyntax, fileSyntax)
    }
    
    func add(directory: String) {
        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: directory),
                                                           includingPropertiesForKeys: [.isRegularFileKey],
                                                           options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                    if fileAttributes.isRegularFile == true && fileURL.pathExtension == "swift" {
                        
                        if let file = File(path: fileURL.path),
                           let syntax = try? StructureAndSyntax(file: file) {
                            
                            let fileSyntax = FileSyntax(outputPath: "/tmp",
                                                        file: file,
                                                        structure: syntax.structure,
                                                        ancestry: [],
                                                        tokens: syntax.syntax,
                                                        blacklist: [],
                                                        dependency: false)
                            add(fileSyntax)
                        }
                    }
                } catch { print(error, fileURL) }
            }
        }
    }

    func recursiveAdd(_ ancestory: [FileSyntax],
                      _ subSyntax: FileSyntax,
                      _ fileSyntax: FileSyntax) {
        let syntax = subSyntax.structure
        
        if syntax.name != nil {
            switch syntax.kind {
            case .class:
                let fullName = AST.getFullName(fileSyntax, ancestory, subSyntax)
                classes[fullName] = subSyntax.clone(ancestry: ancestory)
            case .protocol, .extensionProtocol:
                let fullName = AST.getFullName(fileSyntax, ancestory, subSyntax)
                protocols[fullName] = subSyntax.clone(ancestry: ancestory)
            case .extension, .extensionEnum, .extensionStruct:
                extensions.append(subSyntax)
            case .exprCall:
                calls.append(subSyntax)
            case .functionAccessorAddress, .functionAccessorDidset, .functionAccessorGetter, .functionAccessorModify,
                 .functionAccessorMutableaddress, .functionAccessorRead, .functionAccessorSetter,
                 .functionAccessorWillset, .functionConstructor, .functionDestructor, .functionFree,
                 .functionMethodClass, .functionMethodInstance, .functionMethodStatic, .functionOperator,
                 .functionOperatorInfix, .functionOperatorPostfix, .functionOperatorPrefix, .functionSubscript:
                functions.append(subSyntax)
            default:
                //print("ASTBuilder: unhandled kind \(kind)...")
                break
            }
        }

        if let substructures = syntax.substructure {
            for substructure in substructures {
                recursiveAdd(ancestory + [subSyntax],
                             subSyntax.clone(ancestry: ancestory,
                                             substructure: substructure),
                             fileSyntax)
            }
        }
    }

    func build() -> AST {
        return AST(classes, protocols, extensions)
    }

    func makeIterator() -> ASTBuilderIterator {
        return ASTBuilderIterator(self)
    }

}

/*
class BuildCombinedAST {
    // input: a File and  a syntax structure
    // output: an immutable AST and pass all syntax
    private var astBuilder = ASTBuilder()


    func process(fileSyntaxes: [FileSyntax]) -> [AutogenerateExternalBehaviors.Packet] {
        for arg in fileSyntaxes {
            self.astBuilder.add(arg)
        }
        
        var next: [AutogenerateExternalBehaviors.Packet] = []

        // Once we have all of the relevant structures from all of the files captured, we turn that
        // into an immutable struct which will allow us to share that safely with many actors. Then
        // we process eash structure against the rule set.
        let ast = self.astBuilder.build()

        // Run every individual file pass it to the rulesets
        for syntax in self.astBuilder.files {
            next.append(AutogenerateExternalBehaviors.Packet(ast: ast,
                                                             syntax: syntax,
                                                             fileOnly: true))
        }

        // Run through every syntax structure and pass it to the rulesets
        for syntax in self.astBuilder {
            next.append(AutogenerateExternalBehaviors.Packet(ast: ast,
                                                             syntax: syntax,
                                                             fileOnly: false))
        }

        return next
    }
    
}
*/
