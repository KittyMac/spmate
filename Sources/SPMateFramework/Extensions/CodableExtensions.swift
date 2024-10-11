import Foundation
import Hitch

struct RuntimeError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    public var localizedDescription: String {
        return message
    }
}

func newDateFormatter(utc: Bool) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    if utc {
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
    } else {
        formatter.timeZone = TimeZone.current
    }
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    return formatter
}

public let iso8601DateFormatterUTC = newDateFormatter(utc: true)
public let iso8601DateFormatterLocal = newDateFormatter(utc: false)

public var sharedISO8601DateFormatter = iso8601DateFormatterUTC

private let suppressDefaultValuesKey = CodingUserInfoKey(rawValue: "SuppressDefaultValues")!

public extension Encodable {

    func cloned<T: Decodable>() throws -> T {
        return try self.encoded().decoded()
    }
    
    func compare<T: Encodable>(to other: T) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .formatted(sharedISO8601DateFormatter)
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        
        guard let json1 = try? encoder.encode(self) else { return false }
        guard let json2 = try? encoder.encode(other) else { return false }
        return json1 == json2
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(sharedISO8601DateFormatter)
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try encoder.encode(self)
    }
    
    func json(pretty: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        encoder.dateEncodingStrategy = .formatted(sharedISO8601DateFormatter)
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? #"{"error":"failed to convert string to utf8"}"#
    }
    
    func json(error errorString: String) -> String {
        let noQuotesError = errorString.replacingOccurrences(of: "\"", with: "'")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .formatted(sharedISO8601DateFormatter)
            encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? "{\"error\":\"\(noQuotesError)\"}"
        } catch {
            return "{\"error\":\"\(noQuotesError)\"}"
        }
    }
}

public extension Data {
    func decoded<T: Decodable>() throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try decoder.decode(T.self, from: self)
    }
}

public extension String {
    func decoded<T: Decodable>() throws -> T {
        guard let jsonData = self.data(using: .utf8) else {
            throw RuntimeError("Unable to convert json String to Data")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try decoder.decode(T.self, from: jsonData)
    }
}

public extension Hitch {
    func decoded<T: Decodable>() throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try decoder.decode(T.self, from: self.dataNoCopy())
    }
}

public func jsonSerialization(any: Any, pretty: Bool = false) throws -> String? {
    let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted] : []
    let jsonData = try JSONSerialization.data(withJSONObject: any, options: options)
    return String(data: jsonData, encoding: String.Encoding.utf8)
}

public extension Dictionary {
    func jsonSerialization(pretty: Bool = false) throws -> String? {
        let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted] : []
        let jsonData = try JSONSerialization.data(withJSONObject: self, options: options)
        return String(data: jsonData, encoding: String.Encoding.utf8)
    }
}

public extension Array {
    func jsonSerialization(pretty: Bool = false) throws -> String? {
        let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted] : []
        let jsonData = try JSONSerialization.data(withJSONObject: self, options: options)
        return String(data: jsonData, encoding: String.Encoding.utf8)
    }
}

public extension Data {
    func jsonObject() -> Any? {
        return try? JSONSerialization.jsonObject(with: self, options: [])
    }
}

public extension String {
    func jsonObject() -> Any? {
        guard let data = self.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [])
    }
}
