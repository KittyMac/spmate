import Foundation
import SourceKittenFramework

let functionDefinitionRegexString = #"(.*)\(([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?([\w\d]*:)?\)"#
let functionDefinitionRegex = try! NSRegularExpression(pattern: functionDefinitionRegexString, options: [])

let closureRegexString = #"\(\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\)\s*->\s*(\[?[\.\w\d\?]*\]?)"#
let closureRegex = try! NSRegularExpression(pattern: closureRegexString, options: [])

let tupleRegexString = #"\(\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\s*(\[?[\.\w\d\?]*\]?),?\)"#
let tupleRegex = try! NSRegularExpression(pattern: tupleRegexString, options: [])

struct ASTSimpleType: Equatable, CustomStringConvertible {
    static func == (lhs: ASTSimpleType, rhs: ASTSimpleType) -> Bool {
        return  lhs.kind == rhs.kind
    }

    enum Kind {
        case unknown
        case string
        case int
        case float

        public var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .string: return "String"
            case .int: return "Int"
            case .float: return "Float"
            }
        }
    }

    var kind: Kind = .unknown

    public var description: String {
        return kind.description
    }

    init(infer: String) {
        let trimmed = infer.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("\"") {
            kind = .string
        } else if trimmed.contains("'") {
            kind = .string
        } else if CharacterSet(charactersIn: "0123456789").isSuperset(of: CharacterSet(charactersIn: trimmed)) {
            kind = .int
        } else if CharacterSet(charactersIn: "x0123456789").isSuperset(of: CharacterSet(charactersIn: trimmed)) {
            kind = .int
        } else if CharacterSet(charactersIn: "0123456789.").isSuperset(of: CharacterSet(charactersIn: trimmed)) {
            kind = .float
        } else if trimmed == "String" || trimmed == "NSString" || trimmed == "NSMutableString" {
            kind = .string
        } else if trimmed == "Int" || trimmed == "Int8" || trimmed == "Int16" || trimmed == "Int32" || trimmed == "Int64" {
            kind = .int
        } else if trimmed == "UInt" || trimmed == "UInt8" || trimmed == "UInt16" || trimmed == "UInt32" || trimmed == "UInt64" {
            kind = .int
        } else if trimmed == "Float" || trimmed == "Double" {
            kind = .float
        }
    }
}

struct AST {

    let classes: [String: FileSyntax]
    let protocols: [String: FileSyntax]
    let extensions: [FileSyntax]

    init (_ classes: [String: FileSyntax], _ protocols: [String: FileSyntax], _ extensions: [FileSyntax]) {
        self.classes = classes
        self.protocols = protocols
        self.extensions = extensions
    }

    func error(_ offset: Int64?, _ file: File, _ message: String) -> String {
        let path = file.path ?? "<nopath>"
        if let offset = offset {
            let stringView = StringView.init(file.contents)
            if let (line, character) = stringView.lineAndCharacter(forByteOffset: ByteCount(offset)) {
                return "\(path):\(line):\(character): error: \(message)"
            }
        }
        return "\(path): error: \(message)"
    }

    func warning(_ offset: Int64?, _ file: File, _ message: String) -> String {
        let path = file.path ?? "<nopath>"
        if let offset = offset {
            let stringView = StringView.init(file.contents)
            if let (line, character) = stringView.lineAndCharacter(forByteOffset: ByteCount(offset)) {
                return "\(path):\(line):\(character): warning: \(message)"
            }
        }
        return "\(path): warning: \(message)"
    }

    func findSubstructureOfType(_ structure: SyntaxStructure, _ type: String) -> SyntaxStructure? {
        if structure.typename == type {
            return structure
        }
        if let substructures = structure.substructure {
            for substructure in substructures {
                if let found = findSubstructureOfType(substructure, type) {
                    return found
                }
            }
        }
        return nil
    }

    func getClassOrProtocol(_ name: String?) -> FileSyntax? {
        guard let name = name else { return nil }
        if let actualClass = classes[name] {
            return actualClass
        }
        return protocols[name]
    }

    func getClass(_ name: String?) -> FileSyntax? {
        guard let name = name else { return nil }
        return classes[name]
    }

    func getProtocol(_ name: String?) -> FileSyntax? {
        guard let name = name else { return nil }
        return protocols[name]
    }

    func isSubclassOf(_ syntax: FileSyntax, _ className: String) -> Bool {
        if syntax.structure.kind == .class || syntax.structure.kind == .protocol {
            if let inheritedTypes = syntax.structure.inheritedTypes {
                for ancestor in inheritedTypes {
                    if ancestor.name == className {
                        return true
                    }
                    if let ancestorName = ancestor.name {
                        if let ancestorClass = classes[ancestorName] {
                            if isSubclassOf(ancestorClass, className) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    func isClassOrProtocol(name: String,
                           of matchClassName: String) -> Bool {
        if name == matchClassName {
            return true
        }
        if let actualClass = getClassOrProtocol(name) {
            return isSubclassOf(actualClass, matchClassName)
        }
        return false
    }
    
    func isClassOrProtocol(syntax: FileSyntax,
                           of matchClassName: String) -> Bool {
        if let name = syntax.structure.name {
            return isClassOrProtocol(name: name,
                                     of: matchClassName)
        }
        return false
    }


    private static func recurseClassFullName(_ path: inout [String],
                                             _ current: SyntaxStructure,
                                             _ target: String) -> Bool {
        guard current.substructureExists else { return true }
        
        if let substructures = current.substructure {
            for substructure in substructures {
                guard let name = substructure.name else { continue }
                guard let kind = substructure.kind else { continue }
                
                if  kind == .class ||
                    kind == .enum ||
                    kind == .struct ||
                    kind == .extension ||
                    kind == .extensionEnum ||
                    kind == .extensionStruct {
                
                    if name == target {
                        path.append(name)
                        return false
                    }

                    path.append(name)
                    if recurseClassFullName(&path, substructure, target) == false {
                        return false
                    }
                    path.removeLast()
                }
            }
        }
        return true
    }
    
    static func getFullName(_ file: FileSyntax,
                            _ ancestry: [FileSyntax],
                            _ target: FileSyntax) -> String {
        guard let name = target.structure.name else { return getFullName(file, target) }
        guard let kind = target.structure.kind else { return getFullName(file, target) }
        
        if  kind == .class ||
            kind == .enum ||
            kind == .struct ||
            kind == .extension ||
            kind == .extensionEnum ||
            kind == .extensionStruct {
            
            var fullName = name
            
            for parent in ancestry.reversed() {
                guard let parentName = parent.structure.name else { break }
                guard let parentKind = parent.structure.kind else { break }
                
                if  parentKind == .class ||
                    parentKind == .enum ||
                    parentKind == .struct ||
                    parentKind == .extension ||
                    parentKind == .extensionEnum ||
                    parentKind == .extensionStruct {
                    fullName = "\(parentName).\(fullName)"
                } else {
                    break
                }
            }
                        
            return fullName
        }
        
        return getFullName(file, target)
    }

    static func getFullName(_ file: FileSyntax,
                            _ target: FileSyntax) -> String {
        guard let name = target.structure.name else { return "Unknown" }
        return AST.getFullName(file, name)
    }

    static func getFullName(_ file: FileSyntax,
                            _ targetName: String) -> String {
        let isArray = targetName.hasPrefix("[")

        var actualTargetName = targetName

        if isArray {
            actualTargetName = targetName.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        }

        var names: [String] = []
        _ = AST.recurseClassFullName(&names, file.structure, actualTargetName)
        if names.count == 0 {
            return targetName
        }

        let fullName = names.joined(separator: ".")

        if isArray {
            return "[\(fullName)]"
        }

        return fullName
    }

    func parseFunctionDefinition(_ function: SyntaxStructure) -> (String, [String]) {
        var parameterLabels: [String] = []
        var name = ""

        if let fullName = function.name {
            fullName.matches(functionDefinitionRegex) { (_, groups) in
                // ["_beSetCoreAffinity(theAffinity:arg2:)", "_beSetCoreAffinity", "theAffinity:", "arg2:"]

                name = groups[1]
                if name.hasPrefix("_") {
                    name.removeFirst()
                }

                for idx in 2..<groups.count {
                    var label = groups[idx]
                    if label.hasSuffix(":") {
                        label.removeLast()
                    }
                    parameterLabels.append(label)
                }
            }
        }
        return (name, parameterLabels)
    }

    func parseClosureType(_ typename: String) -> ([String], String) {
        var parameterLabels: [String] = []
        var returnType = ""
        
        // the regex is expensive, try and detect when we can skip it
        if typename.contains("->") == false {
            return (parameterLabels, returnType)
        }

        typename.matches(closureRegex) { (_, groups) in
            // (String, Int, Any) -> Void
            // @esacping (String, Int, Any) -> Void

            if let last = groups.last {
                returnType = last
            }

            for idx in 1..<groups.count-1 {
                let param = groups[idx]
                if param.count > 0 {
                    parameterLabels.append(param)
                }
            }
        }
        return (parameterLabels, returnType)
    }

    func parseTupleType(_ typename: String) -> ([String], String) {
        var parameterLabels: [String] = []
        var returnType = ""
        
        // the regex is expensive, try and detect when we can skip it
        if typename.hasPrefix("(") == false {
            return (parameterLabels, returnType)
        }

        typename.matches(tupleRegex) { (_, groups) in
            // (String, Int, Any)

            if let last = groups.last {
                returnType = last
            }

            for idx in 1..<groups.count-1 {
                let param = groups[idx]
                if param.count > 0 {
                    parameterLabels.append(param)
                }
            }
        }
        return (parameterLabels, returnType)
    }
}
