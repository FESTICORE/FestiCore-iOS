/// 전송 오류 후 재접속 지연. 성공하면 초기화한다.
struct ReconnectBackoff {
  private var attempt = 0

  mutating func nextDelayNanoseconds() -> UInt64 {
    let seconds = min(30, 1 << min(attempt, 5))
    attempt += 1
    return UInt64(seconds) * 1_000_000_000
  }

  mutating func reset() { attempt = 0 }
}
