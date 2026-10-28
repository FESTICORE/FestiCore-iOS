import SwiftUI
import ComposableArchitecture
import Dependencies
import FestiCoreFestivalCatalogInterface
import FestiCoreSharedUI
import Kingfisher

public struct FestiCoreHomeView: View {
  @Dependency(\.festivalCatalogService) private var catalogService
  @Environment(\.scenePhase) private var scenePhase
  @State private var imagePrefetcher: ImagePrefetcher?
  @Bindable public var store: StoreOf<HomeFeature>

  public init(store: StoreOf<HomeFeature>) {
    self.store = store
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          status
          festivalList
          if let festival = store.selectedFestival {
            selectedFestival(festival)
          }
        }
        .padding(20)
      }
      .navigationTitle("FestiCore")
      .refreshable { store.send(.refreshRequested) }
    }
    .task { store.send(.onAppear) }
    .onChange(of: store.selectedPack) { _, pack in
      prefetchImages(for: pack)
    }
    .onChange(of: store.connection) { _, connection in
      if connection == .live { prefetchImages(for: store.selectedPack) }
    }
    .onChange(of: scenePhase) { _, phase in
      store.send(.foregroundChanged(phase == .active))
      if phase == .active { prefetchImages(for: store.selectedPack) }
      else { imagePrefetcher?.stop() }
    }
  }

  private var status: some View {
    HStack(spacing: 8) {
      Image(systemName: store.connection == .live ? "wifi" : "square.and.arrow.down")
      Text(statusText)
        .font(.subheadline)
      Spacer()
    }
    .foregroundStyle(store.connection == .offline ? Color.orange : Color.secondary)
    .accessibilityLabel(statusText)
  }

  private var statusText: String {
    if store.cacheReadFailed {
      return store.selectedPack == nil
        ? "저장된 정보를 읽지 못했습니다 · 연결 후 다시 시도해 주세요"
        : "일부 저장 정보를 읽지 못했습니다 · 표시 중인 팩은 사용할 수 있습니다"
    }
    return switch store.connection {
    case .loading: "저장된 축제를 불러오는 중"
    case .cached: "저장된 정보 표시 중 · 연결되면 갱신됩니다"
    case .connecting: "최신 정보를 확인하는 중"
    case .live: "최신 정보로 갱신됨"
    case .offline:
      store.selectedPack == nil
        ? "오프라인 · 저장된 상세 정보가 없습니다"
        : "오프라인 · 저장된 정보를 표시합니다"
    case .unavailable: "이 축제의 오프라인 팩은 아직 없습니다"
    }
  }

  private var festivalList: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("축제")
        .font(.title2.bold())
      if store.festivals.isEmpty {
        ContentUnavailableView(
          "불러온 축제가 없습니다",
          systemImage: "calendar",
          description: Text("연결되면 축제 목록을 가져옵니다.")
        )
      } else {
        ForEach(store.festivals) { festival in
          Button {
            store.send(.selectFestival(festival.id))
          } label: {
            HStack(spacing: 12) {
              poster(imageURL(festival.thumbnailURL?.absoluteString))
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
              if festival.id == store.selectedFestivalID {
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

  private func selectedFestival(_ festival: FestivalOverview) -> some View {
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
      if let pack = store.selectedPack {
        packDetails(pack)
      } else {
        Text("저장된 상세 정보가 없습니다. 온라인에서 팩을 받으면 오프라인에서도 볼 수 있습니다.")
          .foregroundStyle(.secondary)
      }
    }
  }

  private func packDetails(_ pack: FestivalPackDocument) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      if !pack.performances.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          Text("공연 시간표").font(.headline)
          ForEach(pack.performances) { performance in
            HStack(spacing: 10) {
              poster(imageURL(performance.imageUrl))
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
              poster(imageURL(artist.imageUrl))
                .frame(width: 40, height: 52)
              Text(artist.name).font(.subheadline)
            }
          }
        }
      }
    }
  }

  private func poster(_ url: URL?) -> some View {
    FestiCoreRemoteImage(url: url)
      .content(.fill)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .id("\(url?.absoluteString ?? "")-\(store.connection == .live)")
  }

  private func imageURL(_ value: String?) -> URL? {
    catalogService.imageURL(for: value)
  }

  private func prefetchImages(for pack: FestivalPackDocument?) {
    imagePrefetcher?.stop()
    guard let pack, scenePhase == .active else { return }
    let sourceURLs = [pack.thumbUrl].compactMap(imageURL)
      + (pack.artists ?? []).compactMap { imageURL($0.imageUrl) }
      + pack.performances.compactMap { imageURL($0.imageUrl) }
    var seen = Set<URL>()
    let urls = sourceURLs.filter { seen.insert($0).inserted }.prefix(100)
    guard !urls.isEmpty else { return }
    let prefetcher = ImagePrefetcher(urls: Array(urls))
    prefetcher.maxConcurrentDownloads = 3
    imagePrefetcher = prefetcher
    prefetcher.start()
  }
}
