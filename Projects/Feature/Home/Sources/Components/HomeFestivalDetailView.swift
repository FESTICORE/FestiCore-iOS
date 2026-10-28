import SwiftUI

struct HomeFestivalDetailView: View {
  let festival: FestivalOverview
  let pack: FestivalPackDocument?
  let imageRevision: Int
  let imageURL: (String?) -> URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("축제 상세")
        .font(.title2.bold())
      Text(festival.name)
        .font(.title3.bold())
      if let venue = festival.venue {
        Label(venue, systemImage: "mappin.and.ellipse")
          .font(.subheadline)
      }
      if let first = festival.firstDate {
        Text([first, festival.lastDate].compactMap { $0 }.joined(separator: " – "))
          .font(.subheadline)
      }
      if let pack {
        HomePackDetailsView(pack: pack, imageRevision: imageRevision, imageURL: imageURL)
      } else {
        Text("저장된 상세 정보가 없습니다. 온라인에서 팩을 받으면 오프라인에서도 볼 수 있습니다.")
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct HomePackDetailsView: View {
  let pack: FestivalPackDocument
  let imageRevision: Int
  let imageURL: (String?) -> URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if !pack.performances.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          Text("공연 시간표").font(.headline)
          ForEach(pack.performances) { performance in
            HStack(spacing: 10) {
              HomePosterView(url: imageURL(performance.imageUrl), imageRevision: imageRevision)
                .frame(width: 40, height: 52)
              VStack(alignment: .leading, spacing: 3) {
                Text(performance.artist ?? "공연")
                  .font(.subheadline.bold())
                Text([performance.startsAt, performance.stageName]
                  .compactMap { $0 }.joined(separator: " · "))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
          }
        }
      }
      if let artists = pack.artists, !artists.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          Text("출연진").font(.headline)
          ForEach(artists, id: \.name) { artist in
            HStack(spacing: 10) {
              HomePosterView(url: imageURL(artist.imageUrl), imageRevision: imageRevision)
                .frame(width: 40, height: 52)
              Text(artist.name).font(.subheadline)
            }
          }
        }
      }
    }
  }
}
