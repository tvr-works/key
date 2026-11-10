import CryptoKit
import Foundation

/// Opens a published adoption from the exact authenticated permanent checkpoint.
/// This never signs or publishes shared objects. The existing adoption validator
/// proves the owner signature, unchanged roster and fully resealed plaintexts.
struct V3RecoveryProfileCatchUpService: Sendable {
  let source: any V3ImmutableObjectReading
  let checkpoints: any V3ManifestCheckpointStoring
  let cache: any V3CheckpointManifestCaching
  let session: V3DeviceWrappedVaultKeySessionStore
  let ownership: [any V3ImmutableTransactionRecoveryAnchorStoring]
  var limits: V3ManifestRepositoryLimits = .standard

  func advance(
    from parent: V3DeviceWrappedTrustedCheckpoint, manifestData: Data,
    identity: any V3DeviceWrappedVaultKeyUnwrapping,
    continuing ticket: V3DeviceWrappedVaultKeySessionStore.AuthenticationTicket
  ) throws -> V3DeviceWrappedVaultKeySessionStore.AuthenticationTicket {
    do {
      let oldKey = try session.load(
        vaultID: parent.checkpoint.vaultID, keyID: parent.envelope.body.keyID)
      let envelope = try V3RecoveryManifestCodec().parseEnvelope(manifestData)
      let snapshot = try observe(parent)
      guard snapshot.objects[envelope.digest]?.bytes == manifestData,
        let signer = envelope.authorizations.first?.signerDeviceID,
        let owner = parent.envelope.body.fields.devices.first(where: {
          $0.identity.deviceID == signer && $0.status == .active
        }),
        identity.vaultID == parent.checkpoint.vaultID,
        envelope.body.fields.devices.contains(.init(identity: identity.publicIdentity, status: .active)),
        let wrapper = envelope.body.fields.wrappedKeys.first(where: {
          $0.recipientDeviceID == identity.publicIdentity.deviceID
        })
      else { throw V3RecoveryValidationError.invalidTransition }
      let validator = V3RecoveryProfileAdoptionValidator(limits: limits)
      var candidate = V3RecoveryProfileAdoptionCandidate(
        expectedCheckpoint: parent.checkpoint, envelope: envelope, stagedEntries: [])
      try validator.preflight(
        candidate, parent: parent, currentVaultKey: oldKey, expectedOwner: owner.identity)
      var retained: [V3EntryObjectKey: V3EncryptedEntry] = [:]
      var totalBytes = 0
      func entries(_ fields: V3DeviceWrappedManifestFields) throws -> [V3EntryObjectKey: V3EncryptedEntry] {
        var result: [V3EntryObjectKey: V3EncryptedEntry] = [:]
        for record in fields.entries {
          let address = try V3RecoveryMergeMutationValidator.address(record)
          if retained[address] == nil {
            guard retained.count < limits.maximumReferencedEntryObjects else {
              throw V3RecoveryValidationError.resourceLimit
            }
            let bytes = try V3ExactTransitionRepository(source: source, limits: limits).readEntry(address)
            guard bytes.count <= limits.maximumTotalEntryBytes - totalBytes else {
              throw V3RecoveryValidationError.resourceLimit
            }
            guard Data(SHA256.hash(data: bytes)) == address.digest else {
              throw V3RecoveryValidationError.invalidObject
            }
            totalBytes += bytes.count
            retained[address] = try V3EntryCipher().parse(bytes)
          }
          result[address] = retained[address]
        }
        return result
      }
      let before = try entries(parent.envelope.body.fields)
      candidate = .init(
        expectedCheckpoint: parent.checkpoint, envelope: envelope,
        stagedEntries: Array(try entries(envelope.body.fields).values))
      try requireState(parent.checkpoint, ticket: ticket)
      let nextKey = try identity.unwrapDeviceWrappedVaultKey(
        wrapper.wrappedKey,
        context: envelope.body.deviceContext(recipientDeviceID: identity.publicIdentity.deviceID),
        reason: "Open this Mac's access to the recovery-enabled vault.")
      try session.requireCurrent(ticket)
      try validator.validate(
        candidate, parent: parent, currentEntries: before, currentVaultKey: oldKey,
        nextVaultKey: nextKey, expectedOwner: owner.identity)
      try requireUnchanged(snapshot, parent: parent)
      try requireEntries(retained)
      try requireState(parent.checkpoint, ticket: ticket)
      let checkpoint = try V3ManifestCheckpoint(
        vaultID: parent.checkpoint.vaultID, envelopeDigest: envelope.digest)
      try checkpoints.replaceCheckpoint(
        checkpoint.canonicalBytes, expectedCheckpoint: parent.checkpoint.canonicalBytes,
        vaultID: checkpoint.vaultID)
      try? cache.store(envelope.canonicalBytes, for: checkpoint)
      try requireUnchanged(snapshot, parent: parent)
      try requireEntries(retained)
      try requireState(checkpoint, ticket: ticket)
      return try session.install(
        nextKey, vaultID: checkpoint.vaultID, keyID: envelope.body.fields.keyID,
        authenticationTicket: ticket)
    } catch {
      session.invalidate()
      throw error
    }
  }

  private func requireEntries(_ entries: [V3EntryObjectKey: V3EncryptedEntry]) throws {
    let repository = V3ExactTransitionRepository(source: source, limits: limits)
    for (address, entry) in entries {
      guard try repository.readEntry(address) == entry.canonicalBytes else {
        throw V3RecoveryValidationError.sourceChanged
      }
    }
  }

  private func observe(_ parent: V3DeviceWrappedTrustedCheckpoint) throws -> V3RecoveryManifestGraph {
    var graph = V3RecoveryManifestGraph(source: source, limits: limits, maximumParentEdges: 16_384)
    _ = try graph.loadInventory(floor: parent.checkpoint.envelopeDigest)
    guard graph.objects[parent.checkpoint.envelopeDigest]?.bytes == parent.envelope.canonicalBytes else {
      throw V3RecoveryValidationError.sourceChanged
    }
    _ = try graph.anchoredOrder(
      floor: parent.checkpoint.envelopeDigest, vaultID: parent.checkpoint.vaultID)
    return graph
  }

  private func requireUnchanged(
    _ observed: V3RecoveryManifestGraph, parent: V3DeviceWrappedTrustedCheckpoint
  ) throws {
    let fresh = try observe(parent)
    guard observed.listedDigests == fresh.listedDigests,
      observed.countedObjects == fresh.countedObjects,
      observed.objects.mapValues(\.bytes) == fresh.objects.mapValues(\.bytes)
    else { throw V3RecoveryValidationError.sourceChanged }
  }

  private func requireState(
    _ checkpoint: V3ManifestCheckpoint,
    ticket: V3DeviceWrappedVaultKeySessionStore.AuthenticationTicket
  ) throws {
    try session.requireCurrent(ticket)
    guard try checkpoints.loadCheckpoint(vaultID: checkpoint.vaultID) == checkpoint.canonicalBytes else {
      throw V3RecoveryContentCatchUpError.checkpointChanged
    }
    for store in ownership where try store.loadRecoveryAnchor(vaultID: checkpoint.vaultID) != nil {
      throw V3RecoveryVaultUnlockError.mutationPending
    }
  }
}
