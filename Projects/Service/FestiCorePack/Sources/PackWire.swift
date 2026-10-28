import Foundation
import FestiCorePackInterface

enum PackWire {
  static let maxPackBytes = 8 * 1024 * 1024
  private static let chunkBytes = 48 * 1024

  static func request(festivalID: String, requestID: String, etag: String?) throws -> String {
    var data: [String: String] = ["festivalId": festivalID]
    if let etag { data["ifNoneMatch"] = etag }
    let message: [String: Any] = ["event": "pack.get", "requestId": requestID, "data": data]
    let bytes = try JSONSerialization.data(withJSONObject: message)
    guard bytes.count <= 1024, let text = String(data: bytes, encoding: .utf8) else {
      throw PackSyncError.invalidMessage
    }
    return text
  }

  static func decode(_ text: String) throws -> Message {
    guard text.utf8.count <= 4 * 1024 * 1024,
          let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
          let event = object["event"] as? String else { throw PackSyncError.invalidMessage }
    return Message(event: event, requestID: object["requestId"] as? String, data: object["data"] as? [String: Any])
  }

  struct Message {
    let event: String
    let requestID: String?
    let data: [String: Any]?
  }

  static func cachedPack(from message: Message, festivalID: String) throws -> CachedFestivalPack {
    guard let data = message.data,
          let id = data["festivalId"] as? String, id == festivalID,
          let version = data["packVersion"] as? Int, version > 0,
          let etag = data["etag"] as? String, !etag.isEmpty, etag.utf8.count <= 128,
          let pack = data["pack"] as? [String: Any],
          let bytes = try? JSONSerialization.data(withJSONObject: pack),
          bytes.count <= maxPackBytes,
          PackCache.isValid(bytes, festivalID: festivalID, version: version) else {
      throw PackSyncError.invalidPack
    }
    return CachedFestivalPack(festivalID: festivalID, packVersion: version, etag: etag, pack: bytes)
  }

  static func chunkedPack(
    start: Message, socket: any PackSocket, requestID: String,
    festivalID: String, timeoutNanoseconds: UInt64
  ) async throws -> (CachedFestivalPack, Bool) {
    guard let data = start.data,
          data["festivalId"] as? String == festivalID,
          let version = data["packVersion"] as? Int, version > 0,
          let etag = data["etag"] as? String, !etag.isEmpty, etag.utf8.count <= 128,
          let total = data["totalBytes"] as? Int, total > 0, total <= maxPackBytes,
          let count = data["chunkCount"] as? Int, count == (total + chunkBytes - 1) / chunkBytes,
          let digest = data["sha256"] as? String, digest.count == 64,
          digest.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }) else {
      throw PackSyncError.invalidChunk
    }
    var bytes = Data()
    var hadUpdateHint = false
    bytes.reserveCapacity(total)
    for index in 0..<count {
      let (chunk, chunkHint) = try await transferMessage(
        on: socket, festivalID: festivalID, timeoutNanoseconds: timeoutNanoseconds
      )
      hadUpdateHint = hadUpdateHint || chunkHint
      guard chunk.event == "pack.chunk", chunk.requestID == requestID,
            let chunkData = chunk.data,
            chunkData["index"] as? Int == index,
            let base64 = chunkData["base64"] as? String,
            let part = Data(base64Encoded: base64),
            part.count == min(chunkBytes, total - bytes.count),
            bytes.count + part.count <= total else { throw PackSyncError.invalidChunk }
      bytes.append(part)
    }
    let (complete, completeHint) = try await transferMessage(
      on: socket, festivalID: festivalID, timeoutNanoseconds: timeoutNanoseconds
    )
    hadUpdateHint = hadUpdateHint || completeHint
    guard complete.event == "pack.complete", complete.requestID == requestID,
          bytes.count == total, PackCache.digest(bytes) == digest,
          PackCache.isValid(bytes, festivalID: festivalID, version: version) else {
      throw PackSyncError.invalidChunk
    }
    return (CachedFestivalPack(festivalID: festivalID, packVersion: version, etag: etag, pack: bytes), hadUpdateHint)
  }

  static func receiveText(on socket: any PackSocket, timeoutNanoseconds: UInt64) async throws -> String {
    try await withThrowingTaskGroup(of: String.self) { group in
      group.addTask { try await socket.receive() }
      group.addTask {
        try await Task.sleep(nanoseconds: timeoutNanoseconds)
        socket.cancel()
        throw PackSyncError.timeout
      }
      guard let result = try await group.next() else { throw PackSyncError.timeout }
      group.cancelAll()
      return result
    }
  }

  private static func transferMessage(
    on socket: any PackSocket, festivalID: String, timeoutNanoseconds: UInt64
  ) async throws -> (Message, Bool) {
    var hadUpdateHint = false
    while true {
      let message = try decode(try await receiveText(on: socket, timeoutNanoseconds: timeoutNanoseconds))
      if message.event != "pack.updated" { return (message, hadUpdateHint) }
      if message.data?["festivalId"] as? String == festivalID { hadUpdateHint = true }
    }
  }
}
