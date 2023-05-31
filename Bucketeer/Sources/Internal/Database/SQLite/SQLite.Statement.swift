import Foundation
import SQLite3

extension SQLite {
    final class Statement {
        private let pointer: OpaquePointer

        init(pointer: OpaquePointer) {
            self.pointer = pointer
        }

        @discardableResult
        func step() throws -> Bool {
            let result = sqlite3_step(pointer)
            guard result == SQLITE_ROW || result == SQLITE_DONE else {
                throw Error.failedToStep(.init(pointer: pointer, result: result))
            }
            return result == SQLITE_ROW
        }

        func bind(name: String, value: Any) throws -> Statement {
            let result: Int32
            let bindName = ":\(name)"
            if let v = value as? Int {
                result = pointer.bind(value: v, name: bindName)
            } else if let v = value as? String {
                result = pointer.bind(value: v, name: bindName)
            } else if let v = value as? Data {
                result = pointer.bind(value: v, name: bindName)
            } else {
                throw Error.unsupportedType
            }
            guard result == SQLITE_OK else {
                throw Error.failedToBind(.init(pointer: pointer, result: result))
            }
            return self
        }

        func string(at index: Int32) -> String {
            pointer.string(at: index)
        }

        func int(at index: Int32) -> Int32 {
            pointer.int(at: index)
        }

        func data(at index: Int32) -> Data {
            pointer.data(at: index)
        }

        func reset() throws {
            let result = sqlite3_reset(pointer)
            guard result == SQLITE_OK else {
                throw Error.failedToFinalize(.init(pointer: pointer, result: result))
            }
        }

        func finalize() throws {
            let result = sqlite3_finalize(pointer)
            guard result == SQLITE_OK else {
                throw Error.failedToFinalize(.init(pointer: pointer, result: result))
            }
        }
    }
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension OpaquePointer {
    func bind(value: Int, name: String) -> Int32 {
        return sqlite3_bind_int(self, sqlite3_bind_parameter_index(self, name), Int32(value))
    }

    func bind(value: String, name: String) -> Int32 {
        return sqlite3_bind_text(self, sqlite3_bind_parameter_index(self, name), (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
    }

    func bind(value: Data, name: String) -> Int32 {
        let bytes = [UInt8](value)
        return sqlite3_bind_blob(self, sqlite3_bind_parameter_index(self, name), bytes, Int32(bytes.count), SQLITE_TRANSIENT)
    }

    func string(at index: Int32) -> String {
        NSString(utf8String: sqlite3_column_text(self, index)) as? String ?? ""
    }

    func int(at index: Int32) -> Int32 {
        sqlite3_column_int(self, index)
    }

    func data(at index: Int32) -> Data {
        let i8bufptr = UnsafeBufferPointer(
            start: sqlite3_column_blob(self, index).assumingMemoryBound(to: UInt8.self),
            count: Int(sqlite3_column_bytes(self, index))
        )
        return Data(buffer: i8bufptr)
    }
}
