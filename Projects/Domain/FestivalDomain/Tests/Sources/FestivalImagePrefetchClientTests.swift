import Dependencies
import FestivalDomain
import FestivalDomainInterface
import Testing

struct FestivalImagePrefetchClientTests {
  @Test func liveImagePrefetchDependencyIsRegistered() async {
    func requireLiveDependency<Key: DependencyKey>(_: Key.Type) {}
    requireLiveDependency(FestivalImagePrefetchClient.self)

    let client = FestivalImagePrefetchClient.liveValue
    await client.start([])
    await client.stop()
  }

}
