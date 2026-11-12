import CryptoKit
import Foundation

enum V3DeviceWrappedCatchUpError: Error, Equatable, LocalizedError {
    case temporaryUnavailable
    case checkpointChanged
    case authenticationCancelled
    case deviceRevoked
    case upgradeRequired
    case recoveryRequired

    var errorDescription: String? {
        switch self {
        case .temporaryUnavailable:
            "Authenticated newer vault state is not completely available from the file provider yet."
        case .checkpointChanged:
            "The trusted vault checkpoint changed during catch-up. Retry the operation."
        case .authenticationCancelled:
            "Device authentication was cancelled during vault catch-up."
        case .deviceRevoked:
            "This Mac has been revoked and cannot open the next vault-key epoch."
        case .upgradeRequired:
            "Newer authenticated vault history requires a newer version of Key."
        case .recoveryRequired:
            "Authenticated vault catch-up found invalid or substituted state. Recovery is required."
        }
    }
}

protocol V3DeviceWrappedSameEpochCatchUpStepServicing: Sendable {
    func inspect(
        trusted: V3DeviceWrappedTrustedCheckpoint,
        vaultKey: Data
    ) throws -> V3DeviceWrappedCatchUpPlan

    func advance(
        trusted: V3DeviceWrappedTrustedCheckpoint,
        vaultKey: Data,
        expectedCheckpoint: V3ManifestCheckpoint,
        manifestDigest: Data
    ) throws -> V3DeviceWrappedTrustedCheckpoint
}

/// Read-only inspection and guarded one-manifest advancement used by the
/// authority-aware catch-up coordinator while it owns mutation serialization.
struct V3DeviceWrappedSameEpochCatchUpStepService:
    V3DeviceWrappedSameEpochCatchUpStepServicing,
    Sendable
{
    private let vaultID: String
    private let repositoryObserver: any V3DeviceWrappedRepositoryObserving
    private let source: any V3ImmutableObjectReading
    private let checkpointStore: any V3ManifestCheckpointStoring
    private let cache: any V3CheckpointManifestCaching
    private let limits: V3ManifestRepositoryLimits
    private let planner: V3DeviceWrappedCatchUpPlanner
    private let contentValidator: V3DeviceWrappedCheckpointContentValidator
    private let envelopeCodec = V3DeviceWrappedManifestEnvelopeCodec()

    init(
        vaultID: String,
        repositoryObserver: any V3DeviceWrappedRepositoryObserving,
        source: any V3ImmutableObjectReading,
        checkpointStore: any V3ManifestCheckpointStoring,
        cache: any V3CheckpointManifestCaching,
        limits: V3ManifestRepositoryLimits = .standard
    ) {
        precondition(isValidV3UUID(vaultID))
        self.vaultID = vaultID
        self.repositoryObserver = repositoryObserver
        self.source = source
        self.checkpointStore = checkpointStore
        self.cache = cache
        self.limits = limits
        planner = V3DeviceWrappedCatchUpPlanner(limits: limits)
        contentValidator = V3DeviceWrappedCheckpointContentValidator(
            source: source,
            limits: limits
        )
    }

    func inspect(
        trusted: V3DeviceWrappedTrustedCheckpoint,
        vaultKey: Data
    ) throws -> V3DeviceWrappedCatchUpPlan {
        guard trusted.checkpoint.vaultID == vaultID else {
            throw V3DeviceWrappedCatchUpError.recoveryRequired
        }
        let observation: V3DeviceWrappedRepositoryObservation
        do {
            observation = try repositoryObserver.observeRepository(
                from: trusted,
                vaultKeys: [vaultKey]
            )
        } catch let error as V3ImmutableTransactionError {
            throw catchUpError(for: error)
        } catch {
            throw V3DeviceWrappedCatchUpError.recoveryRequired
        }
        guard observation.checkpoint == trusted.checkpoint else {
            throw V3DeviceWrappedCatchUpError.checkpointChanged
        }

        do {
            return try planner.plan(observation, vaultID: vaultID)
        } catch {
            throw V3DeviceWrappedCatchUpError.recoveryRequired
        }
    }

    func advance(
        trusted: V3DeviceWrappedTrustedCheckpoint,
        vaultKey: Data,
        expectedCheckpoint: V3ManifestCheckpoint,
        manifestDigest: Data
    ) throws -> V3DeviceWrappedTrustedCheckpoint {
        guard expectedCheckpoint == trusted.checkpoint else {
            throw V3DeviceWrappedCatchUpError.checkpointChanged
        }
        let manifestData = try loadManifest(manifestDigest)
        let envelope: V3DeviceWrappedManifestEnvelope
        do {
            envelope = try envelopeCodec.parse(manifestData)
        } catch {
            throw V3DeviceWrappedCatchUpError.recoveryRequired
        }
        guard envelope.parents == [expectedCheckpoint.envelopeDigest],
              hasSameAuthority(envelope, trusted.envelope),
              envelope.authorizations.isEmpty,
              (try? V3ManifestAuthenticator.isValidAuthenticationTag(
                  envelope.authenticationTag,
                  canonicalContent: envelope.canonicalContentBytes,
                  vaultID: vaultID,
                  vaultKey: vaultKey
              )) == true
        else {
            throw V3DeviceWrappedCatchUpError.recoveryRequired
        }

        switch try contentValidator.validate(
            entries: envelope.body.entries,
            vaultID: vaultID
        ) {
        case .ready:
            break
        case .incomplete:
            throw V3DeviceWrappedCatchUpError.temporaryUnavailable
        case .invalid, .resourceLimitExceeded:
            throw V3DeviceWrappedCatchUpError.recoveryRequired
        }

        let checkpoint: V3ManifestCheckpoint
        do {
            checkpoint = try V3ManifestCheckpoint(
                vaultID: vaultID,
                envelopeDigest: manifestDigest
            )
            try checkpointStore.replaceCheckpoint(
                checkpoint.canonicalBytes,
                expectedCheckpoint: trusted.checkpoint.canonicalBytes,
                vaultID: vaultID
            )
        } catch V3ManifestCheckpointStoreError.conflict {
            throw V3DeviceWrappedCatchUpError.checkpointChanged
        } catch {
            throw V3DeviceWrappedCatchUpError.recoveryRequired
        }

        // The provider object was reopened immediately before the guarded
        // checkpoint change. Caching is an availability optimization; failure
        // cannot revoke the authority now held by the local checkpoint.
        try? cache.store(manifestData, for: checkpoint)
        return V3DeviceWrappedTrustedCheckpoint(
            checkpoint: checkpoint,
            envelope: envelope
        )
    }

    private func loadManifest(_ digest: Data) throws -> Data {
        let read: V3RepositoryObjectRead
        do {
            read = try source.readManifest(
                digest: digest,
                maximumBytes: limits.maximumManifestBytes
            )
        } catch {
            throw V3DeviceWrappedCatchUpError.recoveryRequired
        }
        switch read {
        case let .available(data)
            where data.count <= limits.maximumManifestBytes
                && Data(SHA256.hash(data: data)) == digest:
            return data
        case .unavailable:
            throw V3DeviceWrappedCatchUpError.temporaryUnavailable
        case .available, .invalid, .tooLarge:
            throw V3DeviceWrappedCatchUpError.recoveryRequired
        }
    }

    private func hasSameAuthority(
        _ lhs: V3DeviceWrappedManifestEnvelope,
        _ rhs: V3DeviceWrappedManifestEnvelope
    ) -> Bool {
        lhs.body.keyID == rhs.body.keyID
            && lhs.body.authorityTransitionID
                == rhs.body.authorityTransitionID
            && lhs.body.devices == rhs.body.devices
            && lhs.body.wrappedKeys == rhs.body.wrappedKeys
    }

    private func catchUpError(
        for error: V3ImmutableTransactionError
    ) -> V3DeviceWrappedCatchUpError {
        switch error {
        case .referencedEntryUnavailable, .publishedManifestUnavailable:
            .temporaryUnavailable
        case .expectedHeadsChanged:
            .checkpointChanged
        case .invalidAncestryProof, .unresolvedConflict,
            .candidateDoesNotMatchAutomaticMerge, .duplicateStagedEntry,
            .invalidStagedEntry, .objectTooLarge, .referencedEntryInvalid,
            .publishedManifestInvalid:
            .recoveryRequired
        }
    }
}
