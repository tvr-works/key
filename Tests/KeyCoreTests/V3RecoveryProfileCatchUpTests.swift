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
  @Test func offlineMemberCrossesAdoptionAndTwoRegistrationsThenReadsWritesAndReopens() throws {
    let f = try Fixture(registrations: 2)
    defer { f.remove() }
    let runtime = f.runtime()
    try runtime.unlock()
    #expect(try runtime.read(name: "account/密碼", allowStale: false).plaintext == "Adoption fixture secret")
    #expect(try runtime.status().health == .ready)
    #expect(f.checkpoints.value == f.head.canonicalBytes)
    try f.owner.perform(.editEntry) { operation in
      try runtime.authorizeMutation()
      try runtime.edit(
        name: "account/密碼", secret: "changed after adoption", type: .secret,
        operationID: operation.operationID)
    }
    runtime.lock()
    #expect(try runtime.read(name: "account/密碼", allowStale: false).plaintext == "changed after adoption")
    #expect(f.pending.allSatisfy { $0.value == nil })
  }

  @Test(arguments: [false, true])
  func missingAdoptionCiphertextKeepsOldCheckpointUntilExactDelivery(allowStale: Bool) throws {
    let f = try Fixture()
    defer { f.remove() }
    let entry = try #require(f.adoption.stagedEntries.first)
    let path = f.entryURL(entry)
    let data = try Data(contentsOf: path)
    try FileManager.default.removeItem(at: path)
    let runtime = f.runtime()
    #expect(throws: VaultUXServiceError.vaultIncomplete) {
      _ = try runtime.read(name: "account/密碼", allowStale: allowStale)
    }
    #expect(f.checkpoints.value == f.core.base.checkpoint.canonicalBytes)
    #expect(f.core.member.unwraps == 1) // The old local floor only.
    try data.write(to: path)
    #expect(try runtime.read(name: "account/密碼", allowStale: false).plaintext == "Adoption fixture secret")
  }

  @Test func cancellationDuringAdoptionUnwrapDoesNotAdvanceOrRestoreSession() throws {
    let f = try Fixture()
    defer { f.remove() }
    try f.session.install(
      V3RecoveryRegistrationTestSupport.oldKey, vaultID: f.core.base.checkpoint.vaultID,
      keyID: f.core.base.envelope.body.keyID)
    f.core.member.cancelUnwrap = true
    #expect(throws: (any Error).self) { try f.runtime().unlock() }
    #expect(f.checkpoints.value == f.core.base.checkpoint.canonicalBytes)
    #expect(!f.session.hasResidentKey)
  }

  @Test func lockDuringAdoptionUnwrapCannotAdvanceOrInstallAKey() throws {
    let f = try Fixture()
    defer { f.remove() }
    try f.session.install(CoreKey.oldKey, vaultID: CoreKey.vaultID, keyID: f.core.base.envelope.body.keyID)
    f.core.member.onUnwrap = { f.session.invalidate() }
    #expect(throws: (any Error).self) { try f.runtime().unlock() }
    #expect(f.checkpoints.value == f.core.base.checkpoint.canonicalBytes)
    #expect(!f.session.hasResidentKey)
  }

  @Test func competingAdoptionsRefuseBeforeTheNewWrapperIsOpened() throws {
    let f = try Fixture()
    defer { f.remove() }
    let sibling = try f.core.build()
    try f.seed(sibling.envelope.canonicalBytes, entries: sibling.stagedEntries)
    #expect(throws: (any Error).self) { try f.runtime().unlock() }
    #expect(f.checkpoints.value == f.core.base.checkpoint.canonicalBytes)
    #expect(f.core.member.unwraps == 1)
  }

  @Test func siblingArrivingDuringUnwrapCannotAdvanceTheCheckpoint() throws {
    let f = try Fixture()
    defer { f.remove() }
    let sibling = try f.core.build()
    try f.session.install(CoreKey.oldKey, vaultID: CoreKey.vaultID, keyID: f.core.base.envelope.body.keyID)
    f.core.member.onUnwrap = {
      try f.seed(sibling.envelope.canonicalBytes, entries: sibling.stagedEntries)
    }
    #expect(throws: (any Error).self) { try f.runtime().unlock() }
    #expect(f.checkpoints.value == f.core.base.checkpoint.canonicalBytes)
    #expect(!f.session.hasResidentKey)
  }

  @Test func checkpointConflictCannotInstallTheRecoveryKey() throws {
    let f = try Fixture()
    defer { f.remove() }
    f.checkpoints.rejectAdvance = true
    #expect(throws: (any Error).self) { try f.runtime().unlock() }
    #expect(f.checkpoints.value == f.core.base.checkpoint.canonicalBytes)
    #expect(!f.session.hasResidentKey)
  }

  @Test func firstOrdinaryWriteCanCrossAdoptionWithoutAnEarlierUnlockCommand() throws {
    let f = try Fixture(registrations: 2)
    defer { f.remove() }
    let runtime = f.runtime()
    let handler = KeyServiceHandler(
      keyStore: MemoryVaultKeyStore(keyData: CoreKey.oldKey),
      entryStore: EntryStore(rootURL: f.root),
      mutationOwner: f.owner, vaultUXService: runtime,
      vaultReader: runtime, vaultMutator: runtime, vaultSession: runtime)
    #expect(handler.handle(.editManual(name: "account/密碼", secret: "first command writes", type: .secret)) == .success())
    #expect(handler.handle(.get(name: "account/密碼")) == .success("first command writes"))
  }

  @Test func permanentVaultStillSupportsNormalReadWriteAndReopen() throws {
    let f = try Fixture(publishAdoption: false)
    defer { f.remove() }
    let runtime = f.runtime()
    #expect(try runtime.read(name: "account/密碼", allowStale: false).plaintext == "Adoption fixture secret")
    try f.owner.perform(.editEntry) { operation in
      try runtime.authorizeMutation()
      try runtime.edit(name: "account/密碼", secret: "ordinary permanent edit", type: .secret, operationID: operation.operationID)
    }
    runtime.lock()
    #expect(try runtime.read(name: "account/密碼", allowStale: false).plaintext == "ordinary permanent edit")
  }

  @Test func localPendingAdoptionPreventsImplicitCompletion() throws {
    let f = try Fixture()
    defer { f.remove() }
    f.pending[2].value = Data("local pending ownership".utf8)
    #expect(throws: (any Error).self) { try f.runtime().unlock() }
    #expect(f.checkpoints.value == f.core.base.checkpoint.canonicalBytes)
  }

  @Test func signedAdoptionThatChangesPlaintextCannotAdvanceTheCheckpoint() throws {
    let f = try Fixture(publishAdoption: false)
    defer { f.remove() }
    let original = f.adoption
    var staged = original.stagedEntries
    let index = try #require(staged.firstIndex { $0.context.type == .secret })
    staged[index] = try V3EntryCipher().seal(
      "Changed by a signed but invalid adoption", context: staged[index].context,
      vaultKey: CoreKey.nextKey)
    let old = original.envelope.body
    let body = try V3RecoveryManifestBody(
      fields: V3DeviceWrappedManifestFields(
        vaultID: old.fields.vaultID, keyID: old.fields.keyID,
        authorityTransitionID: old.fields.authorityTransitionID,
        devices: old.fields.devices, wrappedKeys: old.fields.wrappedKeys,
        entries: staged.map { V3ResealedEntry(encryptedEntry: $0).manifestEntry }),
      epochSigningKey: old.epochSigningKey, transitionProof: old.transitionProof,
      recovery: old.recovery)
    let invalid = try f.core.resign(original, body: body, staged: staged)
    try f.seed(invalid.envelope.canonicalBytes, entries: staged)
    #expect(throws: VaultUXServiceError.recoveryRequired) { try f.runtime().unlock() }
    #expect(f.core.member.unwraps == 2)
    #expect(f.checkpoints.value == f.core.base.checkpoint.canonicalBytes)
    #expect(!f.session.hasResidentKey)
  }

  @Test(arguments: [false, true])
  func cancelledHandoffCannotStartColdAuthentication(explicitUnlock: Bool) throws {
    let f = try Fixture()
    defer { f.remove() }
    f.checkpoints.value = f.head.canonicalBytes
    let composed = f.runtime()
    try f.session.install(
      CoreKey.nextKey, vaultID: CoreKey.vaultID, keyID: f.adoption.envelope.body.fields.keyID)
    let ticket = f.session.beginAuthentication()
    let runtime = V3ProfiledVaultRuntime(
      permanent: composed.permanent, recovery: composed.recovery,
      isRecovery: composed.isRecovery,
      prepare: { _ in
        f.session.invalidate()
        return ticket
      }, session: f.session)
    #expect(throws: (any Error).self) {
      if explicitUnlock {
        try runtime.unlock()
      } else {
        _ = try runtime.read(name: "account/密碼", allowStale: false)
      }
    }
    #expect(f.core.member.unwraps == 0)
    #expect(!f.session.hasResidentKey)
  }

  @Test func offlineMemberAdvancesEarlierContentBeforeTheFormatTransition() throws {
    let f = try Fixture(publishAdoption: false)
    defer { f.remove() }
    let before = f.runtime()
    try f.owner.perform(.editEntry) { operation in
      try before.authorizeMutation()
      try before.edit(
        name: "account/密碼", secret: "edited before adoption", type: .secret,
        operationID: operation.operationID)
    }
    let checkpoint = try V3ManifestCheckpoint(canonicalBytes: #require(f.checkpoints.value))
    let repository = V3ExactTransitionRepository(source: f.store, limits: .standard)
    let parent = try V3DeviceWrappedManifestEnvelopeCodec().parse(
      repository.readManifest(checkpoint.envelopeDigest))
    var entries: [V3EntryObjectKey: V3EncryptedEntry] = [:]
    for record in parent.body.fields.entries {
      let address = try V3RecoveryMergeMutationValidator.address(record)
      entries[address] = try V3EntryCipher().parse(repository.readEntry(address))
    }
    let adoption = try V3RecoveryProfileAdoptionBuilder().build(
      from: .init(checkpoint: checkpoint, envelope: parent), currentEntries: entries,
      currentVaultKey: CoreKey.oldKey, nextVaultKey: CoreKey.nextKey,
      owner: f.core.owner, reason: "Software adoption after earlier content")
    try f.seed(adoption.envelope.canonicalBytes, entries: adoption.stagedEntries)
    f.checkpoints.value = f.core.base.checkpoint.canonicalBytes
    f.session.invalidate()
    #expect(try f.runtime().read(name: "account/密碼", allowStale: false).plaintext == "edited before adoption")
    #expect(f.checkpoints.value == (try V3ManifestCheckpoint(
      vaultID: CoreKey.vaultID, envelopeDigest: adoption.envelope.digest)).canonicalBytes)
  }

  @Test func lockWhileWaitingForMutationOwnershipCannotStartAuthentication() throws {
    let owner = WaitingOwner()
    let f = try Fixture(mutationOwner: owner)
    defer { f.remove() }
    let runtime = f.runtime()
    let completion = DispatchGroup()
    let result = ReadFailure()
    completion.enter()
    DispatchQueue.global().async {
      defer { completion.leave() }
      do {
        _ = try runtime.read(name: "account/密碼", allowStale: false)
      } catch {
        result.recordFailure()
      }
    }
    #expect(owner.entered.wait(timeout: .now() + 5) == .success)
    runtime.lock()
    owner.release.signal()
    #expect(completion.wait(timeout: .now() + 5) == .success)
    #expect(result.failed)
    #expect(f.core.member.unwraps == 0)
    #expect(f.checkpoints.value == f.core.base.checkpoint.canonicalBytes)
  }

  private final class WaitingOwner: VaultTransactionMutationOwning, @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    private let owner = VaultTransactionMutationOwner()
    func perform<T>(
      _ kind: VaultTransactionMutationKind,
      _ body: (VaultTransactionMutationContext) throws -> T
    ) throws -> T {
      entered.signal()
      guard release.wait(timeout: .now() + 5) == .success else {
        throw V3RecoveryValidationError.sourceChanged
      }
      return try owner.perform(kind, body)
    }
  }

  private final class ReadFailure: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var failed: Bool { lock.withLock { value } }
    func recordFailure() { lock.withLock { value = true } }
  }

  private typealias CoreKey = V3RecoveryRegistrationTestSupport

  private final class Loader: V3DeviceWrappedIdentityLoading, @unchecked Sendable {
    let identity: V3RecoveryRegistrationTestSupport.Owner
    init(_ identity: V3RecoveryRegistrationTestSupport.Owner) { self.identity = identity }
    func loadDeviceIdentity(vaultID _: String, reason _: String) throws
      -> (any V3DeviceWrappedVaultKeyUnwrapping)? { identity }
  }

  private final class Fixture: @unchecked Sendable {
    typealias Core = V3RecoveryRegistrationTestSupport
    typealias Publication = V3RecoveryPublicationTestSupport
    let core: V3RecoveryAdoptionTestSupport.Fixture
    let adoption: V3RecoveryProfileAdoptionCandidate
    let root: URL
    let store: V3FilesystemTransactionArtifactStore
    let checkpoints: Publication.Checkpoints
    let pending = [Publication.Ownership(), Publication.Ownership(), Publication.Ownership()]
    let cache: V3CheckpointManifestFilesystemCache
    let session = V3DeviceWrappedVaultKeySessionStore()
    let owner: any VaultTransactionMutationOwning
    var head: V3ManifestCheckpoint

    init(
      registrations: Int = 0, publishAdoption: Bool = true,
      mutationOwner: any VaultTransactionMutationOwning = VaultTransactionMutationOwner()
    ) throws {
      owner = mutationOwner
      core = try .init()
      adoption = try core.build()
      root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      store = .init(rootHandle: try VaultRootDirectoryHandle(opening: root))
      let local = root.appendingPathComponent("local-cache")
      try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
      cache = .init(rootHandle: try VaultRootDirectoryHandle(opening: local))
      checkpoints = .init(core.base.checkpoint.canonicalBytes)
      head = try .init(vaultID: Core.vaultID, envelopeDigest: adoption.envelope.digest)
      try cache.store(core.base.envelope.canonicalBytes, for: core.base.checkpoint)
      try seed(core.base.envelope.canonicalBytes, entries: Array(core.entries.values))
      if publishAdoption {
        try seed(adoption.envelope.canonicalBytes, entries: adoption.stagedEntries)
      }
      var parent = adoption.envelope
      var entries = try V3EntrySnapshotValidator(limits: .standard).entryMap(adoption.stagedEntries)
      var key = Core.nextKey
      for _ in 0 ..< registrations {
        let nextKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let credential = try Core.Fixture().credential
        let prepared = try V3RecoveryRegistrationBuilder().prepare(
          checkpoint: head, parent: parent, currentEntries: entries,
          currentVaultKey: key, nextVaultKey: nextKey, credential: credential,
          occupancy: .absent, owner: core.owner, reason: "Software registration")
        parent = prepared.candidate
        try seed(parent.canonicalBytes, entries: prepared.stagedEntries)
        head = try .init(vaultID: Core.vaultID, envelopeDigest: parent.digest)
        entries = try V3EntrySnapshotValidator(limits: .standard).entryMap(prepared.stagedEntries)
        key = nextKey
      }
    }

    func seed(_ bytes: Data, entries: [V3EncryptedEntry]) throws {
      let op = VaultTransactionOperationID()
      for entry in entries {
        let address = Publication.address(entry)
        try store.stageEntry(entry.canonicalBytes, entryID: address.entryID, digest: address.digest, operationID: op)
        try store.publishStagedEntry(entry.canonicalBytes, entryID: address.entryID, digest: address.digest, operationID: op)
      }
      let digest = Data(SHA256.hash(data: bytes))
      try store.stageManifest(bytes, digest: digest, operationID: op)
      try store.publishStagedManifest(bytes, digest: digest, operationID: op)
    }

    func entryURL(_ entry: V3EncryptedEntry) -> URL {
      root.appendingPathComponent("entries/\(entry.context.entryID)/\(v3LowercaseHex(Data(SHA256.hash(data: entry.canonicalBytes)))).json")
    }

    func runtime() -> V3ProfiledVaultRuntime {
      let loader = Loader(core.member)
      let unlock = V3DeviceWrappedVaultUnlockRuntime(
        vaultID: Core.vaultID, checkpointStore: checkpoints, source: store, cache: cache,
        identityLoader: loader, session: session)
      let observation = V3LiveDeviceWrappedRepositoryObserver(
        source: store, checkpointStore: checkpoints, cache: cache)
      let content = V3DeviceWrappedSameEpochCatchUpStepService(
        vaultID: Core.vaultID, repositoryObserver: observation, source: store,
        checkpointStore: checkpoints, cache: cache)
      let keys = V3DeviceWrappedKeyTransitionCatchUpStepService(
        vaultID: Core.vaultID, stateManager: unlock, source: store, cache: cache,
        loadIdentity: { _, _ in loader.identity })
      let coordinator: @Sendable (any VaultTransactionMutationOwning) -> V3DeviceWrappedCatchUpCoordinator = { owner in
        .init(vaultID: Core.vaultID, mutationOwner: owner, stateLoader: unlock,
          contentSteps: content,
          keyTransitionDiscovery: V3DeviceWrappedKeyTransitionDiscovery(
            source: self.store, supportsRecoveryAdoption: true),
          keyTransitionSteps: keys)
      }
      let permanent = V3DeviceWrappedVaultRuntime(
        runtime: V3DeviceWrappedReadOnlyVaultRuntime(source: store, unlockRuntime: unlock),
        mutationService: V3DeviceWrappedVaultMutationService(
          stateLoader: unlock, objectStore: store, checkpointStore: checkpoints,
          recoveryAnchorStore: pending[0], cache: cache,
          catchUp: { operationID in
            try coordinator(DirectVaultTransactionMutationOwner(operationID: operationID)).catchUp()
          }),
        session: session, catchUp: { try coordinator(self.owner).catchUp() },
        lockSession: { unlock.lock() })
      let recovery = V3RecoveryVaultRuntime(
        vaultID: Core.vaultID, objectStore: store, checkpointStore: checkpoints,
        transactionOwnershipStore: pending[0], registrationOwnershipStore: pending[1],
        adoptionOwnershipStore: pending[2], cache: cache, identityLoader: loader,
        session: session, mutationOwner: owner)
      return .composing(
        permanent: permanent, recovery: recovery, vaultID: Core.vaultID,
        source: store, checkpoints: checkpoints, cache: cache, identities: loader,
        ownership: pending, session: session, mutationOwner: owner, makeCoordinator: coordinator)
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
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
