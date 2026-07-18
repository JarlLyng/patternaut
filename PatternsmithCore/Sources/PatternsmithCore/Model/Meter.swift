import Foundation

/// A time signature, e.g. 4/4 or 7/8.
public struct Meter: Equatable, Sendable, Codable {
    public var numerator: Int
    public var denominator: Int

    public init(_ numerator: Int, _ denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public static let fourFour = Meter(4, 4)
    public static let sevenEight = Meter(7, 8)
    public static let threeFour = Meter(3, 4)
}

extension Meter: CustomStringConvertible {
    public var description: String { "\(numerator)/\(denominator)" }
}
