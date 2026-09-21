import Foundation

/// One complete Server-Sent Event.
struct SSEEvent: Equatable {
    /// Value of the `event:` line, or `SSEParser.DEFAULT_EVENT_NAME` when the block
    /// has none (SSE standard's default type for a block with no `event:` line).
    let name: String
    /// All `data:` lines of the block, joined with "\n".
    let data: String
}

/// Turns raw bytes from a streaming HTTP response into complete Server-Sent Events.
///
/// Not thread-safe: create one parser per connection attempt and feed it from a single queue.
///
/// Buffers **bytes**, not `String`. A network chunk can end in the middle of a multi-byte
/// UTF-8 character (for example the 3-byte sequence for "日"), and `String(data:encoding:)`
/// on such a partial chunk returns `nil` — silently dropping data. Keeping the unfinished
/// line as bytes and decoding only once a full line has arrived avoids that.
struct SSEParser {
    static let DEFAULT_EVENT_NAME = "message"

    private static let LF: UInt8 = 0x0A // "\n"
    private static let CR: UInt8 = 0x0D // "\r"
    private static let COLON: UInt8 = 0x3A // ":"

    /// Bytes of the current, not-yet-terminated line.
    private var lineBuffer = Data()
    /// Set when the previous chunk ended with a bare "\r": the next chunk's leading "\n",
    /// if any, is the second half of that same CRLF pair and must be swallowed rather than
    /// treated as its own (empty) line.
    private var skipLeadingLF = false
    /// `event:` value seen so far in the current (unterminated) block, if any.
    private var eventName: String?
    /// `data:` lines seen so far in the current (unterminated) block.
    private var dataLines: [String] = []

    /// Feed the next chunk of bytes from the response. Returns the events that became
    /// complete as a result (often none, since most chunks land mid-block).
    mutating func append(_ chunk: Data) -> [SSEEvent] {
        guard !chunk.isEmpty else { return [] }

        var events: [SSEEvent] = []
        var index = chunk.startIndex

        if skipLeadingLF {
            skipLeadingLF = false
            if chunk[index] == SSEParser.LF {
                index = chunk.index(after: index)
            }
        }

        var lineStart = index
        while index < chunk.endIndex {
            let byte = chunk[index]
            if byte == SSEParser.LF || byte == SSEParser.CR {
                lineBuffer.append(chunk[lineStart..<index])
                if let event = processLine(lineBuffer) {
                    events.append(event)
                }
                lineBuffer.removeAll(keepingCapacity: true)

                var next = chunk.index(after: index)
                if byte == SSEParser.CR {
                    if next < chunk.endIndex, chunk[next] == SSEParser.LF {
                        next = chunk.index(after: next)
                    } else if next == chunk.endIndex {
                        // The "\r" is the last byte of this chunk: a following "\n" (if any)
                        // arrives at the start of the next chunk and belongs to this same break.
                        skipLeadingLF = true
                    }
                }
                index = next
                lineStart = index
            } else {
                index = chunk.index(after: index)
            }
        }

        // Any bytes after the last line break are an unfinished line, held for the next append.
        if lineStart < chunk.endIndex {
            lineBuffer.append(chunk[lineStart..<chunk.endIndex])
        }

        return events
    }

    /// Processes one complete line (without its terminator). Comment lines and recognized
    /// field lines update the in-progress block; a blank line ends the block and, if it had
    /// at least one `data:` line, returns the resulting event.
    private mutating func processLine(_ lineBytes: Data) -> SSEEvent? {
        guard !lineBytes.isEmpty else {
            return endBlock()
        }
        guard lineBytes.first != SSEParser.COLON else {
            return nil // comment line, ignored (still counts as liveness by the caller)
        }

        let line = String(decoding: lineBytes, as: UTF8.self)
        if let value = fieldValue(of: line, field: "data:") {
            dataLines.append(value)
        } else if let value = fieldValue(of: line, field: "event:") {
            eventName = value.isEmpty ? nil : value
        }
        // Any other field (id:, retry:, or a malformed line) is ignored: the backend sends none.
        return nil
    }

    private mutating func endBlock() -> SSEEvent? {
        defer {
            eventName = nil
            dataLines.removeAll(keepingCapacity: true)
        }
        guard !dataLines.isEmpty else { return nil }
        return SSEEvent(name: eventName ?? SSEParser.DEFAULT_EVENT_NAME, data: dataLines.joined(separator: "\n"))
    }

    /// Returns the value after `field` (e.g. "data:") with one leading space/tab stripped,
    /// matching the SSE spec's "single leading space is trimmed" rule, or nil if `line`
    /// doesn't start with `field`.
    private func fieldValue(of line: String, field: String) -> String? {
        guard line.hasPrefix(field) else { return nil }
        var value = Substring(line.dropFirst(field.count))
        if let first = value.first, first == " " || first == "\t" {
            value = value.dropFirst()
        }
        return String(value)
    }
}
