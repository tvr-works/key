import Foundation

enum V3ImmutableTransactionError: Error, Equatable, LocalizedError {
    case invalidAncestryProof
    case unresolvedConflict
    case candidateDoesNotMatchAutomaticMerge
    case duplicateStagedEntry
    case invalidStagedEntry
    case objectTooLarge
    case referencedEntryUnavailable(entryID: String, digest: String)
    case referencedEntryInvalid(entryID: String, digest: String)
    case publishedManifestUnavailable(digest: String)
    case publishedManifestInvalid(digest: String)
    case expectedHeadsChanged

    var errorDescription: String? {
        switch self {
        case .invalidAncestryProof:
            "Version 3 transaction publication requires a checkpoint-linked ancestry proof."
        case .unresolvedConflict:
            "Version 3 vault conflicts must be resolved before publishing a transaction."
        case .candidateDoesNotMatchAutomaticMerge:
            "The candidate manifest does not contain the exact deterministic merge result."
        case .duplicateStagedEntry:
            "A version 3 transaction cannot stage the same immutable entry object twice."
        case .invalidStagedEntry:
            "A staged version 3 entry does not match the candidate manifest or current vault key."
        case .objectTooLarge:
            "The version 3 transaction would exceed a repository resource limit."
        case let .referencedEntryUnavailable(entryID, digest):
            "The candidate manifest references entry '\(entryID)' at digest '\(digest)', but its bytes are not available yet."
        case let .referencedEntryInvalid(entryID, digest):
            "The candidate manifest references invalid entry '\(entryID)' at digest '\(digest)'."
        case let .publishedManifestUnavailable(digest):
            "The published version 3 manifest is not available yet at digest '\(digest)'."
        case let .publishedManifestInvalid(digest):
            "The published version 3 manifest is invalid at digest '\(digest)'."
        case .expectedHeadsChanged:
            "The authenticated vault heads changed while the transaction was being staged."
        }
    }
}

enum V3ImmutableTransactionRecoveryError:
    Error,
    Equatable,
    LocalizedError
{
    case transactionDirectoryUnavailable
    case invalidRecoveryAnchor(vaultID: String)
    case invalidIntent(operationID: String)
    case interruptedTransactionPending(operationID: String)
    case checkpointUnavailable(vaultID: String)
    case vaultKeyUnavailable(keyID: String)
    case invalidRecoveryState(operationID: String)

    var errorDescription: String? {
        switch self {
        case .transactionDirectoryUnavailable:
            "Version 3 transaction recovery is waiting for synchronized transaction state."
        case let .invalidRecoveryAnchor(vaultID):
            "Vault '\(vaultID)' has an invalid device-local transaction recovery anchor."
        case let .invalidIntent(operationID):
            "Version 3 transaction '\(operationID)' has an invalid recovery intent."
        case let .interruptedTransactionPending(operationID):
            "Version 3 transaction '\(operationID)' must be recovered before another mutation can publish."
        case let .checkpointUnavailable(vaultID):
            "The device-local checkpoint for vault '\(vaultID)' is unavailable or invalid."
        case let .vaultKeyUnavailable(keyID):
            "Recovery cannot authenticate the candidate manifest because vault key '\(keyID)' is unavailable."
        case let .invalidRecoveryState(operationID):
            "Version 3 transaction '\(operationID)' contains contradictory or invalid recovery state."
        }
    }
}

enum V3ImmutableTransactionRecoveryOutcome: Equatable, Sendable {
    case nothingToRecover
    case completed(operationID: VaultTransactionOperationID)
    case abandoned(operationID: VaultTransactionOperationID)
    case alreadyCompleted(operationID: VaultTransactionOperationID)
}

/// Stages and publishes immutable repository objects.
///
/// Staging paths are non-authoritative transaction state. Publishing must be
/// no-overwrite and durable before returning. An existing destination is
/// successful only when it contains the exact requested bytes.
protocol V3TransactionArtifactStore: V3ImmutableObjectPublishing {
    func persistRecoveryIntent(
        _ data: Data,
        operationID: VaultTransactionOperationID
    ) throws

    func readRecoveryIntent(
        operationID: VaultTransactionOperationID,
        maximumBytes: Int
    ) throws -> V3RepositoryObjectRead

    func removeRecoveryIntent(
        _ data: Data,
        operationID: VaultTransactionOperationID
    ) throws

}

enum V3ImmutableTransactionPhase: Equatable, Sendable {
    case recoveryAnchorPrepared
    case recoveryIntentPersisted
    case recoveryArmed
    case entryStaged(index: Int)
    case manifestStaged
    case repositoryStateRechecked
    case entryPublished(index: Int)
    case publishedEntriesValidated
    case manifestPublished
    case publishedManifestValidated
    case checkpointAdvanced
    case cleanupCompleted
}

protocol V3ImmutableTransactionPhaseObserving: Sendable {
    func didReach(
        _ phase: V3ImmutableTransactionPhase,
        operationID: VaultTransactionOperationID
    ) throws
}
