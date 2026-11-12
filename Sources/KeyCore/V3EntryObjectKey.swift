import Foundation

struct V3EntryObjectKey: Hashable, Sendable {
    let entryID: String
    let digest: Data
}

func entryObjectKey(
    _ entry: V3ManifestEntry
) throws -> V3EntryObjectKey {
    guard let digest = Base64URL.decodeCanonical(entry.ciphertextDigest),
          digest.count == 32
    else {
        throw V3ImmutableTransactionError.invalidStagedEntry
    }
    return V3EntryObjectKey(entryID: entry.entryID, digest: digest)
}

func entryObjectKeyPrecedes(
    _ lhs: V3EntryObjectKey,
    _ rhs: V3EntryObjectKey
) -> Bool {
    Data(lhs.entryID.utf8).lexicographicallyPrecedes(Data(rhs.entryID.utf8))
        || (lhs.entryID == rhs.entryID
            && lhs.digest.lexicographicallyPrecedes(rhs.digest))
}
