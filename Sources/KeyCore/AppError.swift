import Foundation

public enum AppError: Error, LocalizedError, Equatable {
    case usage(String)
    case invalidEntryName(String)
    case invalidSecret(String)
    case entryExists(String)
    case entryNotFound(String)
    case invalidSecretFile(String)
    case vaultKeyMismatch(String)
    case authUnavailable(String)
    case authFailed(String)
    case invalidConfiguration(String)
    case keychain(String)
    case io(String)
    case service(String)
    case operationRefused(String)

    static let legacyICloudKeyCreationUnsupported = AppError.operationRefused(
        "Cannot create or replace an iCloud Keychain key for an older vault: macOS does not support syncing keys with Key's required approval protection. Existing synchronized keys can still be read and migrated. For a vault that opens on this Mac, run `\(KeyProductIdentity.currentProcess.cliExecutableName) migrate --check` to prepare for migration. After migration, sync the vault folder to share it with another Mac."
    )

    public var errorDescription: String? {
        switch self {
        case let .usage(message),
            let .invalidEntryName(message),
            let .invalidSecret(message),
            let .entryExists(message),
            let .entryNotFound(message),
            let .invalidSecretFile(message),
            let .vaultKeyMismatch(message),
            let .authUnavailable(message),
            let .authFailed(message),
            let .invalidConfiguration(message),
            let .keychain(message),
            let .io(message),
            let .service(message),
            let .operationRefused(message):
            return message
        }
    }

    public var serviceErrorCode: KeyServiceErrorCode {
        switch self {
        case .usage:
            .invalidUsage
        case .invalidEntryName:
            .invalidEntryName
        case .invalidSecret:
            .invalidSecret
        case .entryExists:
            .entryExists
        case .entryNotFound:
            .entryNotFound
        case .invalidSecretFile:
            .invalidSecretFile
        case .vaultKeyMismatch:
            .vaultKeyMismatch
        case .authUnavailable:
            .authenticationUnavailable
        case .authFailed:
            .authenticationFailed
        case .invalidConfiguration:
            .invalidConfiguration
        case .keychain:
            .keychainFailure
        case .io:
            .ioFailure
        case .service:
            .serviceFailure
        case .operationRefused:
            .operationRefused
        }
    }

    public var exitCode: KeyExitCode {
        serviceErrorCode.exitCode
    }
}
