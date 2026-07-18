import Testing
@testable import PatternautCore

@Suite("Log buffer")
struct LogBufferTests {
    @Test("Keeps insertion order and joins as text")
    func orderAndText() {
        var buffer = LogBuffer(capacity: 10)
        buffer.append("a")
        buffer.append("b")
        buffer.append("c")
        #expect(buffer.lines == ["a", "b", "c"])
        #expect(buffer.text == "a\nb\nc")
    }

    @Test("Drops oldest lines beyond capacity")
    func capacity() {
        var buffer = LogBuffer(capacity: 3)
        for i in 1...5 { buffer.append("\(i)") }
        #expect(buffer.lines == ["3", "4", "5"])
    }

    @Test("Capacity is at least 1; clear empties it")
    func edges() {
        var buffer = LogBuffer(capacity: 0)
        #expect(buffer.capacity == 1)
        buffer.append("x")
        buffer.append("y")
        #expect(buffer.lines == ["y"])
        buffer.clear()
        #expect(buffer.lines.isEmpty)
        #expect(buffer.text.isEmpty)
    }
}
