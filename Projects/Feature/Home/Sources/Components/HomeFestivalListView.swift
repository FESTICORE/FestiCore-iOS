import SwiftUI

struct HomeFestivalListView: View {
  let festivals: [FestivalOverview]
  let selectedFestivalID: String?
  let imageRevision: Int
  let imageURL: (String?) -> URL?
  let onSelect: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("축제")
        .font(.title2.bold())
      if festivals.isEmpty {
        ContentUnavailableView(
          "불러온 축제가 없습니다",
          systemImage: "calendar",
          description: Text("연결되면 축제 목록을 가져옵니다.")
        )
      } else {
        ForEach(festivals) { festival in
          Button {
            onSelect(festival.id)
          } label: {
            HStack(spacing: 12) {
              HomePosterView(url: imageURL(festival.thumbnailURL?.absoluteString), imageRevision: imageRevision)
                .frame(width: 56, height: 72)
              VStack(alignment: .leading, spacing: 4) {
                Text(festival.name)
                  .font(.headline)
                if let venue = festival.venue {
                  Text(venue).font(.caption).foregroundStyle(.secondary)
                }
                if festival.isCached {
                  Label("오프라인 저장됨", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                }
              }
              Spacer()
              if festival.id == selectedFestivalID {
                Image(systemName: "checkmark.circle.fill")
                  .accessibilityLabel("선택됨")
              }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}
