import Foundation

protocol V3ProfiledVaultServicing:
  VaultReadServicing, VaultMutationServicing, VaultUXServicing, VaultSessionServicing {}

extension V3DeviceWrappedVaultRuntime: V3ProfiledVaultServicing {}
extension V3RecoveryVaultRuntime: V3ProfiledVaultServicing {}

/// Selects ordinary access from device-local authority on every operation.
/// The supplied preparation can authenticate a published format transition;
/// directory contents alone never select the recovery runtime.
struct V3ProfiledVaultRuntime: V3ProfiledVaultServicing {
  let permanent: V3DeviceWrappedVaultRuntime
  let recovery: V3RecoveryVaultRuntime
  let isRecovery: @Sendable () throws -> Bool
  let prepare: @Sendable (VaultTransactionOperationID?) throws -> V3DeviceWrappedVaultKeySessionStore.AuthenticationTicket?
  let session: V3DeviceWrappedVaultKeySessionStore

  static func composing(
    permanent: V3DeviceWrappedVaultRuntime, recovery: V3RecoveryVaultRuntime,
    vaultID: String, source: any V3ImmutableObjectReading,
    checkpoints: any V3ManifestCheckpointStoring, cache: any V3CheckpointManifestCaching,
    identities: any V3DeviceWrappedIdentityLoading,
    ownership: [any V3ImmutableTransactionRecoveryAnchorStoring],
    session: V3DeviceWrappedVaultKeySessionStore, mutationOwner: any VaultTransactionMutationOwning,
    makeCoordinator: @escaping @Sendable (any VaultTransactionMutationOwning) -> V3DeviceWrappedCatchUpCoordinator
  ) -> Self {
    let isRecovery: @Sendable () throws -> Bool = {
      if case .recovery = try v3SelectedCheckpointProfile(
        vaultID: vaultID, checkpoints: checkpoints, source: source, cache: cache
      ).profile { return true }
      return false
    }
    return .init(
      permanent: permanent, recovery: recovery, isRecovery: isRecovery,
      prepare: { operationID in
        guard try !isRecovery() else { return nil }
        let admission = session.beginAuthentication()
        let owner: any VaultTransactionMutationOwning = operationID.map {
          DirectVaultTransactionMutationOwner(operationID: $0)
        } ?? mutationOwner
        return try owner.perform(.catchUpVault) { context in
          try session.requireCurrent(admission)
          guard try !isRecovery() else { return nil }
          let direct = DirectVaultTransactionMutationOwner(operationID: context.operationID)
          guard case .recoveryAdoption(let parent, let bytes) = try makeCoordinator(direct).catchUp()
          else { return nil }
          let ticket = session.beginAuthentication()
          guard let identity = try identities.loadDeviceIdentity(
            vaultID: vaultID, reason: "Open synchronized changes to the vault.")
          else { throw V3RecoveryVaultUnlockError.identityUnavailable }
          try session.requireCurrent(ticket)
          return try V3RecoveryProfileCatchUpService(
            source: source, checkpoints: checkpoints, cache: cache,
            session: session, ownership: ownership
          ).advance(from: parent, manifestData: bytes, identity: identity, continuing: ticket)
        }
      }, session: session)
  }

  private func selected(_ operationID: VaultTransactionOperationID? = nil, allowStale: Bool = false) throws
    -> any V3ProfiledVaultServicing
  {
    do {
      if let ticket = try translatingV3RecoveryRuntimeErrors({ try prepare(operationID) }) {
        return recovery.continuingSession(ticket)
      }
    } catch is V3RecoveryProfileAdoptionError {
      session.invalidate()
      throw VaultUXServiceError.recoveryRequired
    } catch let error as V3DeviceWrappedCatchUpError {
      guard allowStale && (error == .temporaryUnavailable || error == .checkpointChanged) else {
        throw error
      }
    }
    return try current()
  }

  private func current() throws -> any V3ProfiledVaultServicing {
    try isRecovery() ? recovery : permanent
  }

  func unlock() throws { try selected().unlock() }
  func read(name: String, allowStale: Bool) throws -> VaultReadValue {
    try selected(allowStale: allowStale).read(name: name, allowStale: allowStale)
  }
  func list(allowStale: Bool) throws -> [String] {
    try selected(allowStale: allowStale).list(allowStale: allowStale)
  }
  func status() throws -> VaultStatus { try selected(allowStale: true).status() }
  func authorizeRead(name: String, allowStale: Bool) throws {
    try selected(allowStale: allowStale).authorizeRead(name: name, allowStale: allowStale)
  }
  // The handler already owns mutation serialization here. Actual publication
  // prepares with that operation's direct owner before choosing its runtime.
  func authorizeMutation() throws { try current().authorizeMutation() }
  func conflicts() throws -> [VaultConflictSummary] { try selected().conflicts() }
  func conflict(id: String) throws -> VaultConflictDetail { try selected().conflict(id: id) }
  func conflictValue(id: String, versionID: String) throws -> String {
    try selected().conflictValue(id: id, versionID: versionID)
  }
  func resolve(_ resolutions: [VaultConflictResolution]) throws {
    try current().resolve(resolutions)
  }
  func add(name: String, secret: String, type: SecretEntryType, operationID: VaultTransactionOperationID) throws {
    try selected(operationID).add(name: name, secret: secret, type: type, operationID: operationID)
  }
  func edit(name: String, secret: String, type: SecretEntryType, operationID: VaultTransactionOperationID) throws {
    try selected(operationID).edit(name: name, secret: secret, type: type, operationID: operationID)
  }
  func copy(source: String, destination: String, overwrite: Bool, operationID: VaultTransactionOperationID) throws {
    try selected(operationID).copy(source: source, destination: destination, overwrite: overwrite, operationID: operationID)
  }
  func move(source: String, destination: String, overwrite: Bool, operationID: VaultTransactionOperationID) throws {
    try selected(operationID).move(source: source, destination: destination, overwrite: overwrite, operationID: operationID)
  }
  func remove(name: String, operationID: VaultTransactionOperationID) throws {
    try selected(operationID).remove(name: name, operationID: operationID)
  }
  func resolve(_ resolutions: [VaultConflictResolution], operationID: VaultTransactionOperationID) throws {
    try selected(operationID).resolve(resolutions, operationID: operationID)
  }
  func lock() {
    // Invalidate before waiting for either runtime's request mutex.
    session.invalidate()
    permanent.lock()
    recovery.lock()
  }
  func sessionStatus(at date: Date?) -> KeyHelperStatus { session.sessionStatus(at: date) }
}
