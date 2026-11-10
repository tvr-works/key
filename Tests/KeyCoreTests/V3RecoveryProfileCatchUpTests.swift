import CryptoKit
import Foundation
import Testing

@testable import KeyCore

struct V3RecoveryProfileCatchUpTests {
  @Test func existingMacRecognizesPublishedAdoptionAsUnsupported() throws {
    let fixture = try V3RecoveryAdoptionTestSupport.Fixture()
    let adoption = try fixture.build()
    let source = ProfileCatchUpSource(
      manifests: [
        fixture.base.checkpoint.envelopeDigest: fixture.base.envelope.canonicalBytes,
        adoption.envelope.digest: adoption.envelope.canonicalBytes,
      ],
      entries: Array(fixture.entries.values) + adoption.stagedEntries)
    #expect(throws: V3DeviceWrappedCatchUpError.upgradeRequired) {
      _ = try V3DeviceWrappedKeyTransitionDiscovery(source: source).discover(
        from: fixture.base, currentVaultKey: V3RecoveryRegistrationTestSupport.oldKey)
    }
    #expect(fixture.member.unwraps == 0)
  }
}

private struct ProfileCatchUpSource: V3ImmutableObjectReading {
  let manifests: [Data: Data]
  let entries: [V3EncryptedEntry]

  func manifestDigests(maximumCount: Int) throws -> V3RepositoryDirectoryListing {
    guard manifests.count <= maximumCount else { return .limitExceeded }
    return .available(digests: Array(manifests.keys), objectCount: manifests.count)
  }

  func readManifest(digest: Data, maximumBytes: Int) throws -> V3RepositoryObjectRead {
    guard let data = manifests[digest] else { return .unavailable }
    return data.count <= maximumBytes ? .available(data) : .tooLarge
  }

  func readEntry(entryID: String, digest: Data, maximumBytes: Int) throws -> V3RepositoryObjectRead {
    guard let entry = entries.first(where: {
      $0.context.entryID == entryID && Data(SHA256.hash(data: $0.canonicalBytes)) == digest
    }) else { return .unavailable }
    return entry.canonicalBytes.count <= maximumBytes ? .available(entry.canonicalBytes) : .tooLarge
  }
}
