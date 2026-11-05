import Foundation
import FestivalDomainInterface

/// 라이브 보드의 응답과 수신·오류 표시 메타데이터를 한 상태로 묶는다.
struct FestivalLiveBoardState: Equatable {
  var snapshot: FestivalLiveBoardSnapshot?
  var isUnavailable = false
  var isUnpublished = false
  var clockAnchorAt: Date?
  var receivedAt: Date?
}
