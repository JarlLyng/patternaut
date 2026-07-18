import Testing
@testable import PatternautCore

@Suite("Euclidean rhythms")
struct EuclideanTests {
    /// Renders a boolean rhythm as `x`/`.` for readable assertions.
    func render(_ pattern: [Bool]) -> String {
        pattern.map { $0 ? "x" : "." }.joined()
    }

    @Test("Canonical Euclidean patterns match known rhythms")
    func canonical() {
        #expect(render(Euclidean.rhythm(pulses: 3, steps: 8)) == "x..x..x.")   // tresillo
        #expect(render(Euclidean.rhythm(pulses: 5, steps: 8)) == "x.xx.xx.")   // cinquillo
        #expect(render(Euclidean.rhythm(pulses: 4, steps: 16)) == "x...x...x...x...")
        #expect(render(Euclidean.rhythm(pulses: 2, steps: 5)) == "x.x..")
        #expect(render(Euclidean.rhythm(pulses: 5, steps: 13)) == "x..x.x..x.x..")
    }

    @Test("Edge cases: none, full, clamped")
    func edges() {
        #expect(render(Euclidean.rhythm(pulses: 0, steps: 4)) == "....")
        #expect(render(Euclidean.rhythm(pulses: 4, steps: 4)) == "xxxx")
        #expect(render(Euclidean.rhythm(pulses: 9, steps: 4)) == "xxxx") // clamped
        #expect(Euclidean.rhythm(pulses: 3, steps: 0).isEmpty)
    }

    @Test("Rotation shifts the pattern and wraps")
    func rotation() {
        let base = Euclidean.rhythm(pulses: 3, steps: 8)          // x..x..x.
        #expect(render(Euclidean.rhythm(pulses: 3, steps: 8, rotation: 1)) == "..x..x.x")
        // Rotating by the full length is identity.
        #expect(Euclidean.rhythm(pulses: 3, steps: 8, rotation: 8) == base)
    }

    @Test("Pulse count is preserved")
    func pulseCount() {
        for (k, n) in [(3, 8), (5, 8), (7, 16), (4, 16), (5, 13)] {
            let hits = Euclidean.rhythm(pulses: k, steps: n).filter { $0 }.count
            #expect(hits == k)
        }
    }
}
