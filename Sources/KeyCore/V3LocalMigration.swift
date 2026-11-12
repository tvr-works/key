import Foundation

struct V3LocalMigrationReport: Equatable, Sendable {
    let vaultID: String
    let entryCount: Int
    let secretCount: Int
    let totpCount: Int

    var rendered: String {
        [
            "Migration completed.",
            "Entries migrated: \(entryCount) (\(secretCount) \(secretCount == 1 ? "secret" : "secrets"), \(totpCount) \(totpCount == 1 ? "TOTP entry" : "TOTP entries")).",
            "This Mac now uses the migrated vault. Vault ID: \(vaultID).",
            "Key verified that this Mac can unlock the new vault. Run `\(KeyProductIdentity.currentProcess.cliExecutableName) status` to check it.",
            "Your original vault files were kept unchanged. No files were removed.",
            "Keep the original files while checking the migration. They do not receive later changes from the new vault and cannot restore access to it.",
            "Other Macs are not migrated automatically. Install a compatible release on them, then use `\(KeyProductIdentity.currentProcess.cliExecutableName) help share` to add at least one other Mac before relying on the new vault.",
            "Recovery after losing every enrolled Mac needs a previously registered hardware key and the complete encrypted vault. Migration did not register a recovery key. See `\(KeyProductIdentity.currentProcess.cliExecutableName) recovery --help`."
        ].joined(separator: "\n") + "\n"
    }
}

protocol V3LocalMigrationServicing {
    func migrate(
        operationID: VaultTransactionOperationID
    ) throws -> V3LocalMigrationReport
}

/// Defers stricter v3 root handling and migration-only dependencies until the
/// user explicitly applies migration. Ordinary v2 helper startup and reads do
/// not cross the v3 publication boundary.
struct DeferredV3LocalMigrationService: V3LocalMigrationServicing {
    typealias Factory = () throws -> any V3LocalMigrationServicing

    private let makeService: Factory

    init(makeService: @escaping Factory) {
        self.makeService = makeService
    }

    func migrate(
        operationID: VaultTransactionOperationID
    ) throws -> V3LocalMigrationReport {
        try makeService().migrate(operationID: operationID)
    }
}
