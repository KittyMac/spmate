import Foundation
import SourceKittenFramework

extension String {
    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return self[range]
    }
    
    func matches(_ regex: NSRegularExpression, _ callback: @escaping ((NSTextCheckingResult, [String]) -> Void)) {
        let body = self
        let nsrange = NSRange(location: Int(0), length: Int(count))
        regex.enumerateMatches(in: body, options: [], range: nsrange) { (match, _, _) in
            guard let match = match else { return }

            var groups: [String] = []
            for iii in 0..<match.numberOfRanges {
                if let groupString = body.substring(with: match.range(at: iii)) {
                    groups.append(String(groupString))
                }
            }
            callback(match, groups)
        }
    }

    func matches(_ pattern: String, _ callback: @escaping ((NSTextCheckingResult, [String]) -> Void)) {
        do {
            let body = self
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsrange = NSRange(location: Int(0), length: Int(count))
            regex.enumerateMatches(in: body, options: [], range: nsrange) { (match, _, _) in
                guard let match = match else { return }

                var groups: [String] = []
                for iii in 0..<match.numberOfRanges {
                    if let groupString = body.substring(with: match.range(at: iii)) {
                        groups.append(String(groupString))
                    }
                }
                callback(match, groups)
            }
        } catch { }
    }

    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }

    func deletingSuffix(_ suffix: String) -> String {
        guard self.hasSuffix(suffix) else { return self }
        return String(self.dropLast(suffix.count))
    }
}

struct FileSyntax {
    let outputPath: String
    let file: File
    let structure: SyntaxStructure
    let ancestry: [FileSyntax]
    let tokens: [SyntaxToken]
    let blacklist: [String]
    let dependency: Bool
    
    func clone(ancestry: [FileSyntax]) -> FileSyntax {
        return FileSyntax(outputPath: outputPath,
                          file: file,
                          structure: structure,
                          ancestry: ancestry,
                          tokens: tokens,
                          blacklist: blacklist,
                          dependency: dependency)
    }

    func clone(ancestry: [FileSyntax],
               substructure: SyntaxStructure) -> FileSyntax {
        return FileSyntax(outputPath: outputPath,
                          file: file,
                          structure: substructure,
                          ancestry: ancestry,
                          tokens: tokens,
                          blacklist: blacklist,
                          dependency: dependency)
    }

    func match(_ pattern: String,
               includeComments: Bool = false) -> Int64? {
        var firstOffendingMatchOffset: Int64?

        do {
            let body = self.file.contents
            let structure = self.structure
            let map = self.tokens

            if let bodyoffset = structure.offset, var bodylength = structure.length {
                if bodyoffset + bodylength > body.count {
                    bodylength = Int64(body.count) - bodyoffset
                }
                if bodyoffset + bodylength <= body.count {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsrange = NSRange(location: Int(bodyoffset), length: Int(bodylength))
                    regex.enumerateMatches(in: body, options: [], range: nsrange) { (match, _, stop) in
                        guard let match = match else { return }

                        let fullBodyOffset = Int64(match.range.location)

                        // check this offset against all of the offsets in the syntax map.  If it is
                        // inside of a comment, then we want to ignore this offset
                        if includeComments == false {
                            for commentSection in map {
                                if let type = SyntaxKind(rawValue: commentSection.type) {
                                    let offset = commentSection.offset.value
                                    let length = commentSection.length.value
                                    if fullBodyOffset >= offset && fullBodyOffset <= (offset + length) {
                                        switch type {
                                        case .comment, .commentURL, .commentMark, .docComment, .docCommentField, .string, .stringInterpolationAnchor:
                                            return
                                        default:
                                            break
                                        }
                                    }
                                }
                            }
                        }

                        firstOffendingMatchOffset = fullBodyOffset
                        stop.pointee = true
                    }
                }
            }
        } catch {
            return nil
        }
        return firstOffendingMatchOffset
    }

    func matches(_ pattern: String, _ callback: @escaping ((Int64, NSTextCheckingResult, [String]) -> Void)) {
        do {
            let body = self.file.contents
            let structure = self.structure
            let map = self.tokens

            if let bodyoffset = structure.offset, var bodylength = structure.length {
                if bodyoffset + bodylength > body.count {
                    bodylength = Int64(body.count) - bodyoffset
                }
                if bodyoffset + bodylength <= body.count {
                    let regex = try NSRegularExpression(pattern: pattern, options: [])
                    let nsrange = NSRange(location: Int(bodyoffset), length: Int(bodylength))
                    let matches = regex.matches(in: body, options: [.withTransparentBounds], range: nsrange)
                    
                    for match in matches {
                        let fullBodyOffset = Int64(match.range.location)

                        // check this offset against all of the offsets in the syntax map.  If it is
                        // inside of a comment, then we want to ignore this offset
                        for commentSection in map {
                            if let type = SyntaxKind(rawValue: commentSection.type) {
                                let offset = commentSection.offset.value
                                let length = commentSection.length.value
                                if fullBodyOffset >= offset && fullBodyOffset <= (offset + length) {
                                    switch type {
                                    case .comment, .commentURL, .commentMark, .docComment, .docCommentField, .string, .stringInterpolationAnchor:
                                        return
                                    default:
                                        break
                                    }
                                }
                            }
                        }
                        var groups: [String] = []
                        for iii in 0..<match.numberOfRanges {
                            if let groupString = body.substring(with: match.range(at: iii)) {
                                groups.append(String(groupString))
                            }
                        }
                        callback(fullBodyOffset, match, groups)
                    }
                }
            }
        } catch { print("\(error)") }
    }

    func markup(_ label: String) -> [(ByteCount, String)] {
        let body = self.file.contents
        let structure = self.structure
        let map = self.tokens
        var markup: [(ByteCount, String)] = []

        if let bodyoffset = structure.offset, var bodylength = structure.length {
            if bodyoffset + bodylength > body.count {
                bodylength = Int64(body.count) - bodyoffset
            }
            if bodyoffset + bodylength <= body.count {
                let targetString = "flynn:\(label)"
                // Check all comments inside the body to see if they are flynn commands
                // flynn:<name> <args>
                for commentSection in map {
                    if let type = SyntaxKind(rawValue: commentSection.type) {
                        let offset = commentSection.offset.value
                        if offset >= bodyoffset && offset <= (bodyoffset + bodylength) {
                            switch type {
                            case .comment, .commentURL, .commentMark, .docComment, .docCommentField, .string, .stringInterpolationAnchor:
                                let stringView = StringView.init(body)
                                if let commentString = stringView.substringWithByteRange(commentSection.range) {
                                    if let range = commentString.range(of: targetString) {
                                        markup.append( (commentSection.offset, String(commentString[range.upperBound...])) )
                                    }
                                }
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
        return markup
    }
}
