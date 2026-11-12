import Foundation

protocol VaultMutationServicing: Sendable {
    func add(
        name: String,
        secret: String,
        type: SecretEntryType,
        operationID: VaultTransactionOperationID
    ) throws

    func edit(
        name: String,
        secret: String,
        type: SecretEntryType,
        operationID: VaultTransactionOperationID
    ) throws

    func copy(
        source: String,
        destination: String,
        overwrite: Bool,
        operationID: VaultTransactionOperationID
    ) throws

    func move(
        source: String,
        destination: String,
        overwrite: Bool,
        operationID: VaultTransactionOperationID
    ) throws

    func remove(
        name: String,
        operationID: VaultTransactionOperationID
    ) throws

    func resolve(
        _ resolutions: [VaultConflictResolution],
        operationID: VaultTransactionOperationID
    ) throws
}
