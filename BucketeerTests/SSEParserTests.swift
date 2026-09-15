import XCTest
@testable import Bucketeer

final class SSEParserTests: XCTestCase {

    // MARK: - Helpers

    /// Feeds each chunk (as UTF-8 bytes) to a fresh parser and collects every event returned.
    private func parse(_ chunks: [String]) -> [SSEEvent] {
        var parser = SSEParser()
        var events: [SSEEvent] = []
        for chunk in chunks {
            events.append(contentsOf: parser.append(Data(chunk.utf8)))
        }
        return events
    }

    private func parse(_ whole: String) -> [SSEEvent] {
        parse([whole])
    }

    // MARK: - Basic event format

    func testNamedEventWithData() {
        let events = parse("event: put\ndata: {\"a\":1}\n\n")
        XCTAssertEqual(events, [SSEEvent(name: "put", data: "{\"a\":1}")])
    }

    func testNoEventLineDefaultsToMessage() {
        let events = parse("data: plain\n\n")
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "plain")])
    }

    func testEmptyEventNameDefaultsToMessage() {
        let events = parse("event:\ndata: x\n\n")
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "x")])
    }

    func testExplicitMessageEventName() {
        let events = parse("event: message\ndata: x\n\n")
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "x")])
    }

    func testCommentLinesProduceNoEvent() {
        XCTAssertEqual(parse(":\n\n"), [])
        XCTAssertEqual(parse(": ping\n\n"), [])
    }

    func testMultiLineDataJoinedWithNewline() {
        let events = parse("data: line1\ndata: line2\n\n")
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "line1\nline2")])
    }

    /// Only the single leading space/tab after the colon is stripped (SSE spec rule), not
    /// every leading whitespace character. The real backend always sends exactly one space
    /// (`fmt.Fprintf(w, "event: %s\ndata: %s\n\n", ...)`), so this only documents the exact
    /// rule chosen; it is not exercised by real traffic.
    func testDataValueStripsOnlyTheFirstLeadingSpace() {
        let events = parse("data:  x\n\n") // two spaces after the colon
        XCTAssertEqual(events, [SSEEvent(name: "message", data: " x")])
    }

    func testBlockWithNoDataLineProducesNoEvent() {
        // An `event:` line alone, with no `data:` line, must not emit anything.
        let events = parse("event: put\n\ndata: x\n\n")
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "x")])
    }

    func testEventNameResetsAfterEachBlock() {
        // The second block has no `event:` line, so it must NOT inherit "put" from the first.
        let events = parse("event: put\ndata: a\n\ndata: b\n\n")
        XCTAssertEqual(events, [
            SSEEvent(name: "put", data: "a"),
            SSEEvent(name: "message", data: "b")
        ])
    }

    func testUnterminatedBlockIsNotEmittedUntilBlankLineArrives() {
        var parser = SSEParser()
        XCTAssertEqual(parser.append(Data("data: x\n".utf8)), [])
        XCTAssertEqual(parser.append(Data("\n".utf8)), [SSEEvent(name: "message", data: "x")])
    }

    func testUnknownLinesAreIgnored() {
        let events = parse("id: 1\nretry: 10\ndata\ndata: x\n\n")
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "x")])
    }

    // MARK: - Line endings

    func testCRLFFramingParsesIdenticallyToLF() {
        let events = parse("event: evaluations\r\ndata: {\"c\":3}\r\n\r\ndata: plain\r\n\r\n")
        XCTAssertEqual(events, [
            SSEEvent(name: "evaluations", data: "{\"c\":3}"),
            SSEEvent(name: "message", data: "plain")
        ])
    }

    func testBareCRFraming() {
        let events = parse("data: a\r\r")
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "a")])
    }

    func testCRLFSplitAcrossTwoChunksProducesExactlyOneNewline() {
        // Chunk 1 ends with the \r of a \r\n pair. Without holding it back, normalizing
        // each chunk separately would turn one CRLF into two newlines and split "a" and
        // "b" into two separate events.
        let events = parse(["data: a\r", "\ndata: b\r\n\r\n"])
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "a\nb")])
    }

    func testBlankLineSeparatorSplitAcrossTwoChunksStillProducesTwoEvents() {
        // Chunk 1 ends with the first '\n' of the blank-line separator; chunk 2 supplies
        // the second '\n'.
        let events = parse(["data: a\n", "\ndata: b\n\n"])
        XCTAssertEqual(events, [
            SSEEvent(name: "message", data: "a"),
            SSEEvent(name: "message", data: "b")
        ])
    }

    /// iOS-specific: an empty chunk arriving between a trailing "\r" and the following "\n"
    /// must not produce two line breaks. The pending-CR flag must survive an empty append.
    func testEmptyChunkBetweenSplitCRLFDoesNotDuplicateLineBreak() {
        let events = parse(["data: a\r", "", "\ndata: b\r\n\r\n"])
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "a\nb")])
    }

    // MARK: - Chunking equivalence

    func testMixedPayloadChunkedAtArbitraryByteBoundariesMatchesWholePayload() {
        let payload =
            "event: put\ndata: {\"a\":1}\n\n" +
            "data: plain1\ndata: plain2\n\n" +
            "event: patch\r\ndata: {\"b\":2}\r\n\r\n" + // CRLF framing mixed in
            ":\n\n" +
            "event: evaluations\ndata: {\"c\":3}\n\n"

        let reference = parse(payload)
        XCTAssertFalse(reference.isEmpty)
        XCTAssertEqual(reference.last, SSEEvent(name: "evaluations", data: "{\"c\":3}"))

        for chunkSize in [1, 2, 3, 7] {
            var chunks: [String] = []
            var index = payload.startIndex
            while index < payload.endIndex {
                let end = payload.index(index, offsetBy: chunkSize, limitedBy: payload.endIndex) ?? payload.endIndex
                chunks.append(String(payload[index..<end]))
                index = end
            }
            XCTAssertEqual(parse(chunks), reference, "chunkSize \(chunkSize)")
        }
    }

    /// Guards against re-scanning the whole buffer from the start on every appended chunk:
    /// a large payload delivered in many small chunks must still produce exactly one event
    /// with the full data.
    func testLargePayloadDeliveredInManySmallChunksProducesOneCompleteEvent() {
        let value = String(repeating: "x", count: 200_000)
        let payload = "data: \(value)\n\n"

        var chunks: [String] = []
        var index = payload.startIndex
        while index < payload.endIndex {
            let end = payload.index(index, offsetBy: 1_024, limitedBy: payload.endIndex) ?? payload.endIndex
            chunks.append(String(payload[index..<end]))
            index = end
        }

        let events = parse(chunks)
        XCTAssertEqual(events, [SSEEvent(name: "message", data: value)])
    }

    // MARK: - Bytes and encoding (iOS-specific: Data buffering, not String buffering)

    func testMultiByteUTF8CharactersSplitAcrossOneByteChunks() {
        // "日本€" straddles multiple UTF-8 byte sequences (3+3+3 bytes). Feeding this one
        // byte at a time proves the parser buffers raw bytes and only decodes a complete
        // line, rather than calling String(data:encoding:) per chunk (which would return
        // nil / drop data whenever a chunk ends mid-character).
        let payload = "data: 日本€\n\n"
        let bytes = Array(payload.utf8)

        var parser = SSEParser()
        var events: [SSEEvent] = []
        for byte in bytes {
            events.append(contentsOf: parser.append(Data([byte])))
        }
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "日本€")])
    }

    func testInvalidUTF8BytesDoNotCrashAndProduceReplacementCharacter() {
        var parser = SSEParser()
        var events: [SSEEvent] = []
        events.append(contentsOf: parser.append(Data("data: ".utf8)))
        events.append(contentsOf: parser.append(Data([0xFF, 0xFE])))
        events.append(contentsOf: parser.append(Data("\n\n".utf8)))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.name, "message")
        // Invalid bytes decode to the U+FFFD replacement character rather than crashing.
        XCTAssertTrue(events.first?.data.contains("\u{FFFD}") ?? false)
    }

    func testDataSliceWithNonZeroStartIndexParsesCorrectly() {
        // Data handed over by URLSession can be a slice whose indices don't start at 0.
        let full = Data("XXXXXdata: sliced\n\n".utf8)
        let slice = full[full.index(full.startIndex, offsetBy: 5)...]
        XCTAssertNotEqual(slice.startIndex, 0)

        var parser = SSEParser()
        let events = parser.append(slice)
        XCTAssertEqual(events, [SSEEvent(name: "message", data: "sliced")])
    }
}
